#!/bin/bash

# Functions for BackDupManager

# Check and install of GPG
ensure_gpg_installed() {
    if command -v gpg &> /dev/null; then
        return 0
    fi
    echo "Installing GPG..." >&2
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case "$ID" in
            debian|ubuntu)
                sudo apt update && sudo apt install -y gpg
                ;;
            fedora|centos|rhel)
                sudo dnf install -y gnupg2
                ;;
            arch)
                sudo pacman -S --noconfirm gpg
                ;;
            *)
                echo "$MSG_ERROR: Unsupported distribution. Please install GPG manually." >&2
                log_action "GPG installation failed: Unsupported distribution"
                return 1
                ;;
        esac
    else
        echo "$MSG_ERROR: Cannot detect distribution. Please install GPG manually." >&2
        log_action "GPG installation failed: Cannot detect distribution"
        return 1
    fi
    if ! command -v gpg &> /dev/null; then
        echo "$MSG_ERROR: GPG installation failed" >&2
        log_action "GPG installation failed"
        return 1
    fi
    return 0
}

# Writes when an action was done
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Checks if a directory and file exists
validate_dir() {
    if [[ ! -d "$1" ]]; then
        echo "$MSG_ERROR: Directory '$1' does not exist" >&2
        return 1
    fi
    return 0
}
validate_file() {
    if [[ ! -f "$1" || ! -r "$1" ]]; then
        echo "$MSG_ERROR: File '$1' does not exist or is broken" >&2
        return 1
    fi
    return 0
}

# Checks if path exists
validate_path() {
    if [[ ! -e "$1" || ! -r "$1" ]]; then
        echo "$MSG_ERROR: File '$1' does not exist or is broken" >&2
        return 1
    fi
    return 0
}

# Confirmation dialog
confirm_action() {
    stdbuf -oL printf "%s" "$MSG_CONFIRM" > /dev/tty
    read answer
    if [[ "$LANGUAGE" == "cs" && "${answer,,}" == "a" ]] || [[ "$LANGUAGE" == "en" && "${answer,,}" == "y" ]]; then
        return 0
    else
        return 1
    fi
}

# Clear GPG agent cache
clear_gpg_cache() {
    # echo "DEBUG: Clearing GPG agent cache" >> /tmp/gpg_error.log
    if command -v gpg-connect-agent &> /dev/null; then
        gpg-connect-agent reloadagent /bye >/dev/null 2>> /tmp/gpg_error.log
        # if [[ $? -eq 0 ]]; then
            # echo "DEBUG: GPG agent cache cleared successfully" >> /tmp/gpg_error.log
        # else
            # echo "DEBUG: Failed to clear GPG agent cache, trying to kill agent" >> /tmp/gpg_error.log
            # pkill -f gpg-agent 2>> /tmp/gpg_error.log || echo "DEBUG: Could not kill gpg-agent" >> /tmp/gpg_error.log
        # fi
    # else
        # echo "DEBUG: gpg-connect-agent not available, trying to kill agent" >> /tmp/gpg_error.log
        # pkill -f gpg-agent 2>> /tmp/gpg_error.log || echo "DEBUG: Could not kill gpg-agent" >> /tmp/gpg_error.log
    fi
    return 0
}

# Searches for duplicates in defined directory
find_duplicates() {
    local search_dir="$1"
    if [[ -z "$search_dir" ]]; then
        stdbuf -oL printf "%s" "$MSG_SELECT_DIR" > /dev/tty
        read search_dir
    fi
    if ! validate_dir "$search_dir"; then
        return 1
    fi
    echo "Searching for duplicates in '$search_dir'..." >&2
    > "$DUPLICATES_FILE"
    find "$search_dir" -type f -exec md5sum {} + | sort | uniq -d -w 32 | while read -r hash file; do
        echo "$hash: $file" >> "$DUPLICATES_FILE"
    done
    if [[ -s "$DUPLICATES_FILE" ]]; then
        cat "$DUPLICATES_FILE" >&2
        if confirm_action; then
            echo "$MSG_DUPLICATES_SAVED" >&2
            log_action "Duplicates found and saved to $DUPLICATES_FILE from $search_dir"
            return 0
        else
            rm -f "$DUPLICATES_FILE"
            log_action "Duplicates search cancelled in $search_dir"
            return 1
        fi
    else
        echo "$MSG_ERROR: No duplicates found in '$search_dir'" >&2
        log_action "No duplicates found in $search_dir"
        return 1
    fi
}

# Previews for different actions
preview_files() {
    local type="$1" path="$2"
    # echo "DEBUG: preview_files called with type='$type', path='$path'" >> /tmp/preview_files_error.log
    case "$type" in
        "duplicates")
            stdbuf -oL printf "%s\n" "$MSG_PREVIEW_DUPLICATES" > /dev/tty
            sleep 1
            if validate_file "$DUPLICATES_FILE"; then
                cat "$DUPLICATES_FILE" >&2
            else
                echo "$MSG_ERROR: Duplicates file does not exist or is not readable" >&2
                return 1
            fi
            ;;
        "backup")
            stdbuf -oL printf "%s\n" "$MSG_PREVIEW_BACKUP" > /dev/tty
            sleep 1
            if validate_path "$path"; then
                # echo "DEBUG: Listing files in '$path'" >> /tmp/preview_files_error.log
                ls -l "$path" >&2
            else
                echo "$MSG_ERROR: Invalid path for backup: '$path'" >&2
                return 1
            fi
            ;;
        "restore")
            stdbuf -oL printf "%s\n" "$MSG_PREVIEW_RESTORE" > /dev/tty
            sleep 1
            if validate_file "$path"; then
                if [[ "$path" == *.gpg ]]; then
                    local decrypted_file="/tmp/preview_$$.tar.gz"
                    # echo "DEBUG: Decrypting '$path' to '$decrypted_file' for preview" >> /tmp/preview_files_error.log
                    clear_gpg_cache
                    stdbuf -oL printf "Zadejte heslo pro dešifrování: " > /dev/tty
                    read -s passphrase
                    echo
                    echo "$passphrase" | gpg --batch --yes --pinentry-mode loopback --passphrase-fd 0 -d --output "$decrypted_file" "$path" 2>> /tmp/gpg_error.log
                    if [[ $? -ne 0 ]]; then
                        echo "$MSG_RESTORE_FAIL" >&2
                        cat /tmp/gpg_error.log >&2
                        log_action "Preview decryption failed for $path: $(cat /tmp/gpg_error.log)"
                        rm -f "$decrypted_file"
                        return 1
                    fi
                    tar -tvf "$decrypted_file" 2>> /tmp/preview_files_error.log
                    local tar_status=$?
                    rm -f "$decrypted_file"
                    if [[ $tar_status -ne 0 ]]; then
                        echo "$MSG_ERROR: Failed to preview contents of '$path'" >&2
                        log_action "Preview failed for $path"
                        return 1
                    fi
                else
                    tar -tvf "$path" 2>> /tmp/preview_files_error.log
                    if [[ $? -ne 0 ]]; then
                        echo "$MSG_ERROR: Failed to preview contents of '$path'" >&2
                        log_action "Preview failed for $path"
                        return 1
                    fi
                fi
            else
                echo "$MSG_INVALID_BACKUP" >&2
                return 1
            fi
            ;;
        *)
            echo "$MSG_ERROR: Invalid preview type '$type'" >&2
            log_action "Invalid preview type '$type'"
            return 1
            ;;
    esac
    return 0
}

# Removes the temporary duplicates file with confirmation
delete_duplicates_file() {
    if validate_file "$DUPLICATES_FILE"; then
        stdbuf -oL printf "%s" "$MSG_DELETE_DUPLICATES_FILE" > /dev/tty
        if confirm_action; then
            rm -f "$DUPLICATES_FILE"
            log_action "Temporary duplicates file deleted"
            return 0
        fi
    fi
    return 1
}

# Chooses a backup file from BACKUP_DIR
select_backup() {
    # echo "DEBUG: Checking backup directory '$BACKUP_DIR'" >> /tmp/select_backup_error.log
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "$MSG_ERROR: Backup directory '$BACKUP_DIR' does not exist" >&2
        log_action "Backup directory '$BACKUP_DIR' does not exist"
        return 1
    fi
    if [[ ! -r "$BACKUP_DIR" || ! -x "$BACKUP_DIR" ]]; then
        echo "$MSG_ERROR: Backup directory '$BACKUP_DIR' is not readable or accessible" >&2
        log_action "Backup directory '$BACKUP_DIR' is not readable or accessible"
        return 1
    fi
    # echo "DEBUG: Listing directory contents of '$BACKUP_DIR'" >> /tmp/select_backup_error.log
    ls -l "$BACKUP_DIR" >> /tmp/select_backup_error.log 2>&1
    # echo "DEBUG: Running find command on '$BACKUP_DIR'" >> /tmp/select_backup_error.log
    local tmp_file="/tmp/select_backup_files_$$.tmp"
    find "$BACKUP_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.tar.gz.gpg" \) -print > "$tmp_file" 2>> /tmp/select_backup_error.log
    # echo "DEBUG: find output written to '$tmp_file'" >> /tmp/select_backup_error.log
    if [[ ! -s "$tmp_file" ]]; then
        echo "$MSG_NO_BACKUPS" >&2
        log_action "No .tar.gz or .tar.gz.gpg backups found in $BACKUP_DIR"
        rm -f "$tmp_file"
        return 1
    fi
    local -a backup_files
    mapfile -t backup_files < "$tmp_file"
    # echo "DEBUG: Found ${#backup_files[@]} backup files: ${backup_files[*]}" >> /tmp/select_backup_error.log
    rm -f "$tmp_file"
    if [[ ${#backup_files[@]} -eq 0 ]]; then
        echo "$MSG_NO_BACKUPS" >&2
        log_action "No .tar.gz or .tar.gz.gpg backups found in $BACKUP_DIR"
        return 1
    fi
    # Vynutit výstup na terminál
    stdbuf -oL printf "\033[2J\033[H" > /dev/tty  # Vymazat obrazovku
    stdbuf -oL printf "%s\n" "$MSG_BACKUP_SELECT" > /dev/tty
    for i in "${!backup_files[@]}"; do
        stdbuf -oL printf "%d) %s\n" "$((i+1))" "${backup_files[i]}" > /dev/tty
    done
    # echo "DEBUG: Backup list displayed" >> /tmp/select_backup_error.log
    stdbuf -oL printf "Stiskněte Enter pro pokračování..." > /dev/tty
    read -s
    local choice
    while true; do
        stdbuf -oL printf "Vyberte číslo zálohy (1-%d nebo 'q' pro ukončení): " "${#backup_files[@]}" > /dev/tty
        read -t 30 choice
        # echo "DEBUG: User entered choice '$choice'" >> /tmp/select_backup_error.log
        if [[ "$choice" == "q" ]]; then
            echo "Operace zrušena" >&2
            log_action "Operation cancelled"
            return 1
        fi
        if [[ -z "$choice" || ! "$choice" =~ ^[0-9]+$ || "$choice" -lt 1 || "$choice" -gt "${#backup_files[@]}" ]]; then
            echo "$MSG_ERROR: Neplatný výběr" >&2
            log_action "Invalid selection: '$choice'"
            stdbuf -oL printf "Chcete zkusit znovu? (A/N): " > /dev/tty
            read answer
            if [[ "$LANGUAGE" == "cs" && "${answer,,}" != "a" ]] || [[ "$LANGUAGE" == "en" && "${answer,,}" != "y" ]]; then
                echo "Operace zrušena" >&2
                log_action "Operation cancelled"
                return 1
            fi
        else
            local file="${backup_files[$((choice-1))]}"
            # echo "DEBUG: User selected file '$file'" >> /tmp/select_backup_error.log
            if validate_file "$file"; then
                # echo "DEBUG: Selected backup file '$file' is valid" >> /tmp/select_backup_error.log
                printf "%s" "$file"  # Vrací pouze cestu k souboru
                return 0
            else
                echo "$MSG_INVALID_BACKUP" >&2
                log_action "Invalid backup file selected: '$file'"
                continue
            fi
        fi
    done
}

# Duplicates deletion from DUPLICATES_FILE
delete_duplicates() {
    local search_dir="$1"
    if ! validate_file "$DUPLICATES_FILE"; then
        find_duplicates "$search_dir"
        if [[ $? -ne 0 ]]; then
            return 1
        fi
    fi
    preview_files "duplicates"
    if confirm_action; then
        while IFS=": " read -r hash file; do
            if [[ -z "$first_file" ]]; then
                first_file="$file"
                continue
            fi
            if [[ -f "$file" ]]; then
                rm -f "$file"
                log_action "Deleted duplicate $file"
            fi
        done < "$DUPLICATES_FILE"
        echo "Duplicates deleted" >&2
        log_action "Duplicates deleted"
        delete_duplicates_file
        return 0
    else
        echo "Deletion of duplicates cancelled" >&2
        log_action "Deletion of duplicates cancelled"
        return 1
    fi
}

# Backup from selected path
create_backup() {
    if ! validate_dir "$BACKUP_DIR"; then
        return 1
    fi
    stdbuf -oL printf "%s" "$MSG_SELECT_BACKUP_PATH" > /dev/tty
    read -r backup_path
    # echo "DEBUG: User entered backup_path='$backup_path'" >> /tmp/create_backup_error.log
    if ! validate_path "$backup_path"; then
        return 1
    fi
    backup_path=$(realpath "$backup_path" 2>/dev/null || echo "$backup_path")
    # echo "DEBUG: Normalized backup_path='$backup_path'" >> /tmp/create_backup_error.log
    local backup_file="$BACKUP_DIR/backup_$(date '+%Y%m%d_%H%M%S').tar.gz"
    # echo "DEBUG: Creating backup from '$backup_path' to '$backup_file'" >> /tmp/create_backup_error.log
    preview_files "backup" "$backup_path"
    if [[ $? -ne 0 ]]; then
        echo "$MSG_ERROR: Preview failed for '$backup_path'" >&2
        log_action "Preview failed for backup path '$backup_path'"
        return 1
    fi
    if confirm_action; then
        if [[ -d "$backup_path" ]]; then
            # echo "DEBUG: Backing up directory '$backup_path'" >> /tmp/create_backup_error.log
            tar -czf "$backup_file" -C "$(dirname "$backup_path")" "$(basename "$backup_path")" 2>> /tmp/create_backup_error.log
        else
            # echo "DEBUG: Backing up file '$backup_path'" >> /tmp/create_backup_error.log
            tar -czf "$backup_file" -C "$(dirname "$backup_path")" "$(basename "$backup_path")" 2>> /tmp/create_backup_error.log
        fi
        if [[ $? -eq 0 ]]; then
            echo "Backup created: $backup_file" >&2
            log_action "Backup created at $backup_file from $backup_path"
            if ensure_gpg_installed; then
                stdbuf -oL printf "Chcete zálohu zašifrovat? (A/N): " > /dev/tty
                if confirm_action; then
                    local encrypted_file="${backup_file}.gpg"
                    # echo "DEBUG: Encrypting '$backup_file' to '$encrypted_file'" >> /tmp/create_backup_error.log
                    stdbuf -oL printf "Zadejte heslo pro šifrování: " > /dev/tty
                    read -s passphrase
                    echo
                    clear_gpg_cache
                    echo "$passphrase" | gpg --batch --yes --pinentry-mode loopback --passphrase-fd 0 -c --output "$encrypted_file" "$backup_file" 2>> /tmp/gpg_error.log
                    if [[ $? -eq 0 ]]; then
                        echo "Záloha zašifrována: $encrypted_file" >&2
                        log_action "Backup encrypted at $encrypted_file"
                        stdbuf -oL printf "Chcete smazat původní nezašifrovanou zálohu? (A/N): " > /dev/tty
                        if confirm_action; then
                            rm -f "$backup_file"
                            log_action "Original backup file deleted: $backup_file"
                        fi
                    else
                        echo "$MSG_ENCRYPT_FAIL" >&2
                        cat /tmp/gpg_error.log >&2
                        log_action "Encryption failed for $backup_file: $(cat /tmp/gpg_error.log)"
                        return 1
                    fi
                fi
            else
                echo "$MSG_ERROR: GPG is not installed, backup will not be encrypted" >&2
                log_action "GPG not installed, backup not encrypted: $backup_file"
            fi
            return 0
        else
            echo "$MSG_ERROR: Backup creation failed" >&2
            log_action "Backup creation failed for $backup_path: $(cat /tmp/create_backup_error.log)"
            return 1
        fi
    else
        echo "Backup creation cancelled" >&2
        log_action "Backup creation cancelled for $backup_path"
        return 1
    fi
}

# Restore backup
restore_backup() {
    if ! ensure_gpg_installed; then
        echo "$MSG_ERROR: GPG is not installed" >&2
        log_action "GPG is not installed for restoration"
        return 1
    fi
    if ! validate_dir "$RESTORE_DIR"; then
        echo "$MSG_ERROR: Restore directory '$RESTORE_DIR' does not exist" >&2
        log_action "Restore directory '$RESTORE_DIR' does not exist"
        return 1
    fi
    local backup_file
    # echo "DEBUG: Before calling select_backup for restoration" >> /tmp/select_backup_error.log
    backup_file=$(select_backup 2>> /tmp/select_backup_error.log)  # Odstraněno stdbuf
    local select_status=$?
    # echo "DEBUG: select_backup returned status $select_status, backup_file='$backup_file'" >> /tmp/select_backup_error.log
    if [[ $select_status -ne 0 || -z "$backup_file" ]]; then
        echo "$MSG_ERROR: No valid backup file selected" >&2
        sleep 1
        echo "CHYBA: Nepodařilo se vybrat záložní soubor, zkontrolujte log v /tmp/select_backup_error.log" >&2
        if [[ -f /tmp/select_backup_error.log ]]; then
            cat /tmp/select_backup_error.log >&2
            log_action "No valid backup file selected for restoration: $(cat /tmp/select_backup_error.log)"
        else
            log_action "No valid backup file selected for restoration"
        fi
        return 1
    fi
    if ! validate_file "$backup_file"; then
        echo "$MSG_ERROR: Invalid backup file '$backup_file'" >&2
        sleep 1
        log_action "Invalid backup file for restoration: '$backup_file'"
        return 1
    fi
    preview_files "restore" "$backup_file"
    if [[ $? -ne 0 ]]; then
        echo "$MSG_ERROR: Preview failed for '$backup_file'" >&2
        sleep 1
        log_action "Preview failed for restoration of '$backup_file'"
        return 1
    fi
    if confirm_action; then
        if [[ "$backup_file" == *.gpg ]]; then
            local decrypted_file="/tmp/restore_$$.tar.gz"
            # echo "DEBUG: Decrypting '$backup_file' to '$decrypted_file'" >> /tmp/gpg_error.log
            clear_gpg_cache
            stdbuf -oL printf "Zadejte heslo pro dešifrování: " > /dev/tty
            read -s passphrase
            echo
            echo "$passphrase" | gpg --batch --yes --pinentry-mode loopback --passphrase-fd 0 -d --output "$decrypted_file" "$backup_file" 2>> /tmp/gpg_error.log
            if [[ $? -ne 0 ]]; then
                echo "$MSG_RESTORE_FAIL" >&2
                cat /tmp/gpg_error.log >&2
                log_action "Decryption failed for $backup_file: $(cat /tmp/gpg_error.log)"
                rm -f "$decrypted_file"
                return 1
            fi
            tar -xzf "$decrypted_file" -C "$RESTORE_DIR" 2>> /tmp/restore_backup_error.log
            if [[ $? -eq 0 ]]; then
                echo "Backup restored from $backup_file to $RESTORE_DIR" >&2
                log_action "Backup restored from $backup_file to $RESTORE_DIR"
                rm -f "$decrypted_file"
                return 0
            else
                echo "$MSG_RESTORE_FAIL" >&2
                cat /tmp/restore_backup_error.log >&2
                log_action "Restoration failed for $backup_file: $(cat /tmp/restore_backup_error.log)"
                rm -f "$decrypted_file"
                return 1
            fi
        else
            tar -xzf "$backup_file" -C "$RESTORE_DIR" 2>> /tmp/restore_backup_error.log
            if [[ $? -eq 0 ]]; then
                echo "Backup restored from $backup_file to $RESTORE_DIR" >&2
                log_action "Backup restored from $backup_file to $RESTORE_DIR"
                return 0
            else
                echo "$MSG_RESTORE_FAIL" >&2
                cat /tmp/restore_backup_error.log >&2
                log_action "Restoration failed for $backup_file: $(cat /tmp/restore_backup_error.log)"
                return 1
            fi
        fi
    else
        echo "Restoration cancelled" >&2
        log_action "Restoration cancelled for $backup_file"
        return 1
    fi
}

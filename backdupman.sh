#!/bin/bash

# BackDupManager - Main script

# Get backdupman.sh directory
SCRIPT_DIR=$(dirname "$0")

# Check for config and utils existence
if [[ ! -f "$SCRIPT_DIR/config.sh" ]]; then
    echo "Error: config.sh not found in $SCRIPT_DIR" >&2
    exit 1
fi
if [[ ! -f "$SCRIPT_DIR/utils.sh" ]]; then
    echo "Error: utils.sh not found in $SCRIPT_DIR" >&2
    exit 1
fi

# Config file check
CONFIG_FILE="$HOME/backdupman/backdupman.conf"

# Main menu
main_menu() {
    while true; do
        stdbuf -oL printf "%s\n" "$MSG_MENU_TITLE" > /dev/tty
        stdbuf -oL printf "1) %s\n" "$MSG_DUPLICATES" > /dev/tty
        stdbuf -oL printf "2) %s\n" "$MSG_BACKUP" > /dev/tty
        stdbuf -oL printf "3) %s\n" "$MSG_LOG" > /dev/tty
        stdbuf -oL printf "4) %s\n" "$MSG_CHANGE_LANGUAGE" > /dev/tty
        stdbuf -oL printf "5) %s\n" "$MSG_EXIT" > /dev/tty
        stdbuf -oL printf "Select an option: " > /dev/tty
        read option
        case $option in
            1)
                duplicates_submenu
                ;;
            2)
                backup_submenu
                ;;
            3)
                view_log
                ;;
            4)
                change_language
                ;;
            5)
                echo "Exiting..." >&2
                exit 0
                ;;
            *)
                echo "$MSG_ERROR: Invalid option" >&2
                sleep 1
                ;;
        esac
    done
}

# Duplicates menu
duplicates_submenu() {
    while true; do
        stdbuf -oL printf "%s\n" "$MSG_DUPLICATES_SUBMENU" > /dev/tty
        stdbuf -oL printf "1) %s\n" "$MSG_DUPLICATES_FIND" > /dev/tty
        stdbuf -oL printf "2) %s\n" "$MSG_DUPLICATES_DELETE" > /dev/tty
        stdbuf -oL printf "3) %s\n" "$MSG_DELETE_DUPLICATES_FILE" > /dev/tty
        stdbuf -oL printf "4) %s\n" "$MSG_SUBMENU_BACK" > /dev/tty
        stdbuf -oL printf "Select an option: " > /dev/tty
        read option
        case $option in
            1)
                find_duplicates
                ;;
            2)
                delete_duplicates
                ;;
            3)
                delete_duplicates_file
                ;;
            4)
                break
                ;;
            *)
                echo "$MSG_ERROR: Invalid option" >&2
                sleep 1
                ;;
        esac
    done
}

# Backup menu
backup_submenu() {
    while true; do
        stdbuf -oL printf "%s\n" "$MSG_BACKUP_SUBMENU" > /dev/tty
        stdbuf -oL printf "1) %s\n" "$MSG_BACKUP_CREATE" > /dev/tty
        stdbuf -oL printf "2) %s\n" "$MSG_BACKUP_RESTORE" > /dev/tty
        stdbuf -oL printf "3) %s\n" "$MSG_SUBMENU_BACK" > /dev/tty
        stdbuf -oL printf "Select an option: " > /dev/tty
        read option
        case $option in
            1)
                create_backup
                ;;
            2)
                restore_backup
                ;;
            3)
                break
                ;;
            *)
                echo "$MSG_ERROR: Invalid option" >&2
                sleep 1
                ;;
        esac
    done
}

# Log viewer
view_log() {
    if validate_file "$LOG_FILE"; then
        cat "$LOG_FILE" >&2
    else
        echo "$MSG_ERROR: Log file does not exist or is broken" >&2
    fi
    stdbuf -oL printf "Press Enter to continue..." > /dev/tty
    read
}

# Change language
change_language() {
    stdbuf -oL printf "%s\n" "$MSG_LANGUAGE_PROMPT" > /dev/tty
    select lang in "CS" "EN"; do
        local lang_lower=$(echo "$lang" | tr '[:upper:]' '[:lower:]')
        mkdir -p "$HOME/backdupman" || { echo "Error: Cannot create directory $HOME/backdupman" >&2; exit 1; }
        # echo "DEBUG: Writing to CONFIG_FILE: $CONFIG_FILE" >> /tmp/backdupman_output.log
        echo "language=$lang_lower" > "$CONFIG_FILE" || { echo "Error: Cannot write to $CONFIG_FILE" >&2; exit 1; }
        echo "backup_dir=$BACKUP_DIR" >> "$CONFIG_FILE" || { echo "Error: Cannot write to $CONFIG_FILE" >&2; exit 1; }
        # echo "DEBUG: Reloading config.sh" >> /tmp/backdupman_output.log
        unset LANGUAGE
        source "$SCRIPT_DIR/config.sh"
        # echo "DEBUG: Language set to $lang_lower" >> /tmp/backdupman_output.log
        # echo "DEBUG: CONFIG_FILE content:" >> /tmp/backdupman_output.log
        cat "$CONFIG_FILE" >> /tmp/backdupman_output.log || echo "Error: Cannot read $CONFIG_FILE" >&2
        # echo "DEBUG: MSG_MENU_TITLE is now: $MSG_MENU_TITLE" >> /tmp/backdupman_output.log
        echo "Language changed to $lang" >&2
        stdbuf -oL printf "Press Enter to continue..." > /dev/tty
        read
        break         
    done
    main_menu
}

# Ask for language
# echo "DEBUG: Checking CONFIG_FILE: $CONFIG_FILE" >> /tmp/backdupman_output.log
if [[ -f "$CONFIG_FILE" && -s "$CONFIG_FILE" && $(grep -E '^language=(cs|en)$' "$CONFIG_FILE") ]]; then
    # echo "DEBUG: Valid language set in $CONFIG_FILE, skipping prompt" >> /tmp/backdupman_output.log
    # echo "DEBUG: CONFIG_FILE content at startup:" >> /tmp/backdupman_output.log
    cat "$CONFIG_FILE" >> /tmp/backdupman_output.log || echo "Error: Cannot read $CONFIG_FILE" >&2
    source "$SCRIPT_DIR/config.sh"
    source "$SCRIPT_DIR/utils.sh"
else
    # echo "DEBUG: No CONFIG_FILE, empty, or no valid language set, prompting for language" >> /tmp/backdupman_output.log
    LANGUAGE="en"
    source "$SCRIPT_DIR/config.sh"
    source "$SCRIPT_DIR/utils.sh"
    change_language
fi

# Start main menu
main_menu

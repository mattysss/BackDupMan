#!/bin/bash

# Directories, Language and Text config (Nastavení adresářů, jazyka a textu)
WORKING_DIR=$(pwd)
BACKUP_DIR="$HOME/backdupman/backdupman_backups"
RESTORE_DIR="$HOME/backdupman/backdupman_restored_backups"
LOG_FILE="$HOME/backdupman/backdupman.log"
CONFIG_FILE="$HOME/backdupman/backdupman.conf"
DUPLICATES_FILE="$HOME/backdupman/backdupman_duplicates.txt"

# Make main directory
mkdir -p "$HOME/backdupman" || { echo "Error: Cannot create directory $HOME/backdupman"; exit 1; }
mkdir -p "$RESTORE_DIR" || { echo "Error: Cannot create directory $RESTORE_DIR"; exit 1; }

# Take language from CONFIG_FILE if exists
if [[ -f "$CONFIG_FILE" && -r "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    if [[ "$language" == "cs" || "$language" == "en" ]]; then
        LANGUAGE="$language"
        # echo "DEBUG: Loaded LANGUAGE=$LANGUAGE from $CONFIG_FILE"
    else
        # echo "DEBUG: Invalid language in $CONFIG_FILE, setting default"
        LANGUAGE="en"
    fi
else
    # echo "DEBUG: No CONFIG_FILE found, setting default language"
    LANGUAGE="en"
fi

# Default language if not set
if [[ -z "$LANGUAGE" ]]; then
    # echo "DEBUG: LANGUAGE not set, using default"
    LANGUAGE="en"
fi
# echo "DEBUG: LANGUAGE set to $LANGUAGE"

# English
if [[ "$LANGUAGE" == "en" ]]; then
    MSG_MENU_TITLE="BackDupManager - Main Menu"
    MSG_DUPLICATES="Search and manage duplicates (Searching and deleting duplicates by hash)"
    MSG_BACKUP="Make and manage backups (Backup, encrypt or restore files and directories)"
    MSG_LOG="View log file (Shows actions performed by the script)"
    MSG_CHANGE_LANGUAGE="Change language (CS or EN)"
    MSG_EXIT="Exit (Exit the script)"
    MSG_CONFIRM="Do you wanna proceed? (Y/N): "
    MSG_ERROR="Error"
    MSG_LANGUAGE_PROMPT="Choose language 1) CS 2) EN: "
    MSG_DUPLICATES_SUBMENU="Submenu: Search and manage duplicate files"
    MSG_DUPLICATES_FIND="Find duplicates (Search and save list of duplicates)"
    MSG_DUPLICATES_DELETE="Delete duplicates (Deletes duplicates from saved list or will search for duplicates and delete them)"
    MSG_SUBMENU_BACK="Back to main menu"
    MSG_BACKUP_SUBMENU="Submenu: Make and manage backups"
    MSG_BACKUP_CREATE="Create backup (Creates an archive from files and directories)"
    MSG_BACKUP_ENCRYPT="Encrypt backup (Encrypts an existing backup after selection)"
    MSG_BACKUP_RESTORE="Restore backup (Restores files and directories from the archive)"
    MSG_DUPLICATES_SAVED="Duplicates list saved, will be used for deletion"
    MSG_PREVIEW_DUPLICATES="Preview duplicates"
    MSG_PREVIEW_BACKUP="Preview files for backup"
    MSG_PREVIEW_ENCRYPT="Preview files for encryption"
    MSG_PREVIEW_RESTORE="Preview files for restoration"
    MSG_DELETE_DUPLICATES_FILE="Delete temporary duplicates file (Y/N): "
    MSG_BACKUP_SELECT="Select backup file for encryption (choose number): "
    MSG_NO_BACKUPS="No backups found in the backup directory. Please create a backup first."
    MSG_INVALID_BACKUP="Invalid backup file selected."
    MSG_ENCRYPT_FAIL="Encryption failed"
    MSG_RESTORE_FAIL="Restoration failed"
    MSG_SELECT_DIR="Select directory to search for duplicates: "
    MSG_SELECT_BACKUP_PATH="Select file or directory to backup: "
fi

# Czech
if [[ "$LANGUAGE" == "cs" ]]; then
    MSG_MENU_TITLE="BackDupManager - Hlavní menu"
    MSG_DUPLICATES="Hledat a spravovat duplikáty (Hledání a mazání duplikátů podle hashe)"
    MSG_BACKUP="Vytvořit a spravovat zálohy (Zálohovat, šifrovat nebo obnovit soubory a adresáře)"
    MSG_LOG="Zobrazit log soubor (Ukazuje akce provedené skriptem)"
    MSG_CHANGE_LANGUAGE="Změnit jazyk (CS nebo EN)"
    MSG_EXIT="Konec (Ukončit skript)"
    MSG_CONFIRM="Chcete pokračovat? (A/N)"
    MSG_ERROR="Chyba"
    MSG_LANGUAGE_PROMPT="Zvolte jazyk 1) CS 2) EN: "
    MSG_DUPLICATES_SUBMENU="Podmenu: Hledat a spravovat duplicitní soubory"
    MSG_DUPLICATES_FIND="Najít duplikáty (Hledá a ukládá seznam duplikátů)"
    MSG_DUPLICATES_DELETE="Smazat duplikáty (Maže duplikáty z uloženého seznamu nebo je hledá a maže)"
    MSG_SUBMENU_BACK="Zpět do hlavního menu"
    MSG_BACKUP_SUBMENU="Podmenu: Vytvořit a spravovat zálohy"
    MSG_BACKUP_CREATE="Vytvořit zálohu (Vytvoří archiv ze souborů a adresářů)"
    MSG_BACKUP_ENCRYPT="Šifrovat zálohu (Šifruje existující zálohu po výběru)"
    MSG_BACKUP_RESTORE="Obnovit zálohu (Obnoví soubory a adresáře z archivu)"
    MSG_DUPLICATES_SAVED="Seznam duplikátů uložen, bude použit pro mazání"
    MSG_PREVIEW_DUPLICATES="Náhled duplikátů"
    MSG_PREVIEW_BACKUP="Náhled souborů pro zálohu"
    MSG_PREVIEW_ENCRYPT="Náhled souborů pro šifrování"
    MSG_PREVIEW_RESTORE="Náhled souborů pro obnovení"
    MSG_DELETE_DUPLICATES_FILE="Smazat dočasný soubor s duplikáty (A/N): "
    MSG_BACKUP_SELECT="Vyberte záložní soubor pro šifrování (vyberte číslo): "
    MSG_NO_BACKUPS="V adresáři záloh nejsou žádné zálohy. Nejprve vytvořte zálohu."
    MSG_INVALID_BACKUP="Vybrán neplatný záložní soubor."
    MSG_ENCRYPT_FAIL="Šifrování selhalo"
    MSG_RESTORE_FAIL="Obnova selhala"
    MSG_SELECT_DIR="Vyberte adresář pro hledání duplikátů: "
    MSG_SELECT_BACKUP_PATH="Vyberte soubor nebo adresář k zálohování: "
fi

# Makes backup dir if it does not exist
mkdir -p "$BACKUP_DIR"

if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "$MSG_ERROR: Cannot create backup directory"
    exit 1
fi

# Makes log file or exits script
touch "$LOG_FILE" || { echo "$MSG_ERROR: Cannot create log file"; exit 1; }

# Makes duplicates file or exits script
touch "$DUPLICATES_FILE" || { echo "$MSG_ERROR: Cannot create duplicates file"; exit 1; }

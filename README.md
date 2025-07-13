# BackDupManager

BackDupManager je interaktivní Bash skript pro správu záloh a detekci duplicitních souborů. Podporuje vícejazyčnost (čeština a angličtina), šifrování záloh pomocí GPG, logování operací a jednoduché textové menu pro ovládání.

## Funkce

- Vytváření záloh souborů a složek (.tar.gz)
- Možnost šifrování záloh pomocí GPG (.gpg)
- Obnovení záloh do zvoleného adresáře
- Hledání a mazání duplicitních souborů (na základě hashů)
- Správa logu provedených akcí
- Výběr jazyka (CS / EN)

## Struktura projektu

```
backdupman/
├── backdupman.sh        # Hlavní spouštěcí skript
├── config.sh            # Nastavení jazyků, adresářů a textů
└── utils.sh       # Pomocné funkce (validace, logování, GPG, atd.)
```

## Požadavky

- Bash shell
- GPG (`gpg`)
- `tar`, `md5sum`, `find`, `ls`, `cat`

## Instalace

1. Nakopíruj soubory `backdupman.sh`, `config.sh` a `utils.sh` do jednoho adresáře.
2. Nastav oprávnění
   ```bash
   chmod +x backdupman.sh
   chmod +x config.sh
   chmod +x utils.sh
   ```
4. Spusť hlavní skript:
   ```bash
   ./backdupman.sh
   ```

## Popis menu

### Hlavní menu

```
1) Hledat a spravovat duplikáty
2) Vytvořit a spravovat zálohy
3) Zobrazit log
4) Změnit jazyk
5) Konec
```

### Submenu: Duplikáty

- Najít duplikáty
- Smazat duplikáty
- Smazat dočasný soubor s duplikáty

### Submenu: Zálohy

- Vytvořit zálohu
- Obnovit zálohu

## Jazyková podpora

Při prvním spuštění si uživatel zvolí jazyk (`CS` nebo `EN`). Skript si volbu uloží do souboru `~/backdupman/backdupman.conf`.

## Logování

Všechny akce jsou zapisovány do souboru:

```
~/backdupman/backdupman.log
```

## Cesty

- Zálohy: `~/backdupman/backdupman_backups/`
- Obnova: `~/backdupman/backdupman_restored_backups/`
- Duplikáty: `~/backdupman/backdupman_duplicates.txt`

## Poznámky

- Skript automaticky vytvoří všechny potřebné adresáře.
- Pokud GPG není nainstalované, skript se ho pokusí automaticky nainstalovat podle distribuce.
- Skript používá `stdbuf` pro zajištění výstupu do terminálu při použití `> /dev/tty`.

---

© 2025 – BackDupManager, vytvořil Matěj


# MergeAllAccountsToCSV

Small PowerShell utility to merge account CSVs from Fidelity and Vanguard into a single CSV and an allocation summary.

**Quick Start**

- Requirements: PowerShell 7+ (Windows PowerShell 5.1 may work but newer PowerShell recommended).
- Run from the repository folder or reference full paths.
- Exports from Vanguard should include 'Vanguard' and a date in YYYY-MM-DD or MMM-DD-YYYY format in the file name.
- Exports from Fidelity should include 'Fidelity' in the filename. By default, Fidelity exports include the date.

**Exporting data from custodians**

Fidelity:
    - Log into fidelity.com
    - Click on the **Positions** link
    - Click on the **Download** button, found on the right side of screen just above the table for the first account's positions.
    - A file named Portfolio_Positions_[DATE].csv will be downloaded via your browser. Rename to include 'Fidelity' in the filename.

Example:

```powershell
pwsh -File .\MergeAllAccountsToCSV.ps1 -FileList "S:\path\to\Vanguard_2026-08-15_OfxDownload.csv","S:\path\to\Fidelity_Portfolio_Positions_Aug-15-2026.csv" -OutputFile S:\Investing\Mergefile.csv
```

**Behavior**

- The script reads multiple CSVs, parses holdings, and writes two outputs:
  - Merged portfolio CSV (the `-OutputFile` with the export date appended)
  - Allocation summary CSV (same directory, name appended with `_allocation` and date)
- If `-OutputFile` contains a path, that directory is preserved when the date is appended.

**Configuration (optional)**

You can provide a JSON file with the same base name as the script to override mappings and exclusions. Example file: [MergeAllAccountsToCSV.json](MergeAllAccountsToCSV.json)

Example JSON structure:

```json
{
  "accountMap": {
    "235127901": "Fidelity HSA - Ending 7901",
    "40048860": "Vanguard Brokerage - Ending 8860"
  },
  "accountExcludeList": ["Z39596235"],
  "symbolMap": {
    "VTSAX": "Vanguard Total Stock Market Index Fund Admiral Shares",
    "SPAXX": "Fidelity Government Money Market Fund"
  }
}
```

The script will use values from the JSON if the file exists; otherwise built-in defaults are used.

**Repository files**
- `MergeAllAccountsToCSV.ps1` — main script
- `MergeAllAccountsToCSV.json` — example config (this file is in `.gitignore` by default to avoid committing secrets/local configs)
- `.gitignore` — ignores local JSON and common outputs

**Notes & Tips**
- Use full paths for input/output when running from a different working directory.
- For financial totals, the script currently uses floating-point (`float`) for numeric parsing; consider using `decimal` if exact base‑10 accuracy is required.
- If you want the JSON to be tracked instead of ignored, update `.gitignore` accordingly.

If you want, I can:
- Switch numeric parsing to use `decimal` for monetary accuracy.
- Add a small test fixture and example input files.

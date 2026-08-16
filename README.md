# MergeAllAccountsToCSV

Small PowerShell utility to merge account CSVs from Fidelity and Vanguard into a summary CSV and an across-account allocation summary.

**Quick Start**

- Requirements: PowerShell 7+ (Windows PowerShell 5.1 may work but newer PowerShell recommended).
- Run from the repository folder or reference full paths.
- Exports from Vanguard should include 'Vanguard' and a date in YYYY-MM-DD or MMM-DD-YYYY format in the file name.
- Exports from Fidelity should include 'Fidelity' in the filename. By default, Fidelity exports include the date.

**Exporting data from custodians**

Fidelity:
1. Log into https://www.fidelity.com
2. Click on the **Positions** link
3. Click on the **Download** button, found on the right side of screen just above the table for the first account's positions.
4. A file named *Portfolio_Positions_[DATE].csv* will be downloaded via your browser. Rename to include 'Fidelity' in the filename.

Vanguard:
1. Log into https://www.vanguard.com
2. Click on the **Holdings** link
3. Click on the **Download Center** link to the right
4. Choose "A spreadsheet-compatible CSV File"
5. Choose any date range. The script ignores transactions, so 1 month is fine.
6. Choose all accounts you'd like to export holdings info about
7. Press Download button on bottom right of page. A file named 'OfxDownload.csv' will be downloaded via your browser. Rename this file to include 'Vanguard' and a date in YYYY-MM-DD or MMM-DD-YYYY format in the file name.

Example:

```powershell
pwsh -File .\MergeAllAccountsToCSV.ps1 -FileList "C:\path\to\Vanguard_2026-08-15_OfxDownload.csv","C:\path\to\Fidelity_Portfolio_Positions_Aug-15-2026.csv" -OutputFile C:\Investing\Mergefile.csv
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
    "123456789": "Fidelity account 6789",
    "012345678": "Vanguard account ending in 5678"
  },
  "accountExcludeList": ["234567890"],
  "symbolMap": {
    "Ticker": "Ticker Description",
    "FDRXX": "Fidelity Treasury Money Market Fund"
  }
}
```

The script will use values from the JSON if the file exists; otherwise built-in defaults are used.

**Repository files**
- `MergeAllAccountsToCSV.ps1` — main script
- `.gitignore` — ignores local JSON and common outputs

**Notes & Tips**
- Use full paths for input/output when running from a different working directory.
- For financial totals, the script currently uses floating-point (`float`) for numeric parsing; consider using `decimal` if exact base‑10 accuracy is required.


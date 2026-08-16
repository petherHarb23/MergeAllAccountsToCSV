# MergeAllAccountsToCSV.ps1
# This script merges multiple export files from Fidelity and Vanguard into summary CSV files.
# Each filename should include 'Vanguard' or 'Fidelity', and the date in YYYY-MM-DD or MMM-DD-YYYY format.
# A JSON configuration file with the same base name as this script can be used to customize account and symbol mappings
# while keeping them out of the main script for easier maintenance.
# Usage: 
#   .\MergeAllAccountsToCSV.ps1 -FileList "Vanguard_PJ_2026-08-15_OfxDownload.csv","Fidelity_PJ_Portfolio_Positions_Aug-15-2026" -Outputfile merge.csv
param(
    [Parameter(Mandatory = $true)]
    [object[]]$FileList,
    [string]$OutputFile = "MergedPortfolio.csv"
)

# Account number to name mapping (defaults)
$accountMap = @{
    "123456789" = "Fidelity account 6789" # example account 1
    "012345678" = "Vanguard account ending in 5678" # example account 2
}
# Account numbers to exclude from the merged output (defaults)
$accountExcludeList = @(
    "234567890"  # Example account number to exclude
)

# Symbol to description mapping (defaults)
$symbolMap = @{
    "Ticker" = "Ticker Description" # example mapping
    "FDRXX" = "Fidelity Treasury Money Market Fund" # example mapping
}

<# Can also be loaded from a JSON file with the same base name as this script, e.g., MergeAllAccountsToCSV.json
Example JSON structure:
{
    "accountMap": {
        "123456789": "Fidelity account 6789",
        "012345678": "Vanguard account ending in 5678"
    },
    "accountExcludeList": [
        "234567890"
    ],
    "symbolMap": {
        "Ticker": "Ticker Description",
        "FDRXX": "Fidelity Treasury Money Market Fund"
    }
}  
#>


# Function to extract date from filename or file content. Return as DateTime object.
function Get-ExportFileDate {
    param([string]$FilePath)
    
    $filename = Split-Path -Leaf $FilePath
    # Recognize these filename formats and normalize to yyyy-MM-dd:
    #   DD-MMM-YYYY   (e.g. 13-Jul-2026)
    #   MMM-DD-YYYY   (e.g. Jul-13-2026)
    #   YYYY-MM-DD    (e.g. 2026-07-13)

    $formats = @(
        @{ regex = '(\d{1,2})-([A-Za-z]{3})-(\d{4})'; format = 'dd-MMM-yyyy' },
        @{ regex = '([A-Za-z]{3})-(\d{1,2})-(\d{4})'; format = 'MMM-dd-yyyy' },
        @{ regex = '(\d{4})-(\d{2})-(\d{2})'; format = 'yyyy-MM-dd' }
    )

    foreach ($fmt in $formats) {
        if ($filename -match $fmt.regex) {
            $matched = $matches[0]
            $dt = $null
            try {
                $dt = [datetime]::ParseExact($matched, $fmt.format, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None)
                return $dt
            } catch {}
        }
    }

    # If not in filename, search file content for "Date downloaded" like 7/13/2026 or 07/13/2026
    if (Test-Path $FilePath) {
        $content = Get-Content -Path $FilePath -Raw
        if ($content -match 'Date[d ]downloaded[:\s]+(\d{1,2}/\d{1,2}/\d{4})') {
            $dateStr = $matches[1]
            $dt = $null
            try { $dt = [datetime]::Parse($dateStr); return $dt } catch {}
        }
    }

    return Get-Date
}

# Function to parse Fidelity CSV
function Parse-FidelityFile {
    param([string]$FilePath)
    $results = @()
    if (-not (Test-Path $FilePath)) { return $results }

    try {
        $csv = Import-Csv -Path $FilePath -ErrorAction Stop
    } catch {
        return $results
    }

    foreach ($row in $csv) {
        # Skip rows that look like headers or missing a symbol
        $symbol = $null
        if ($row.PSObject.Properties.Match('Symbol')) { $symbol = $row.Symbol }
        elseif ($row.PSObject.Properties.Match('symbol')) { $symbol = $row.'symbol' }
        if (-not $symbol -or $symbol -eq 'Symbol') { continue }
        $symbol = $symbol.TrimEnd('*')

        $description = if ($symbolMap.ContainsKey([string]$symbol)) { 
            $symbolMap[[string]$symbol] 
        } else { 
            if ($row.PSObject.Properties.Match('Description')) { $row.Description } else { $row.description } 
        }
        $sharesRaw = if ($row.PSObject.Properties.Match('Quantity')) { $row.Quantity } elseif ($row.PSObject.Properties.Match('Shares')) { $row.Shares } else { $null }
        $priceRaw = if ($row.PSObject.Properties.Match('Last price')) { $row.'Last price' } elseif ($row.PSObject.Properties.Match('Price')) { $row.Price } else { $null }
        $valueRaw = if ($row.PSObject.Properties.Match('Current value')) { $row.'Current value' } elseif ($row.PSObject.Properties.Match('Value')) { $row.Value } else { $null }

        $shares = 0.0
        try { if ($sharesRaw) { $shares = [float]($sharesRaw -replace '[^0-9\.-]', '') } } catch {}
        $price = 0.0
        try { if ($priceRaw) { $price = [float]($priceRaw -replace '[^0-9\.-]', '') } } catch {}
        $value = 0.0
        try { if ($valueRaw) { $value = [float]($valueRaw -replace '[^0-9\.-]', '') } else { $value = $shares * $price } } catch { $value = $shares * $price }

        if (([string]::IsNullOrWhiteSpace([string]$sharesRaw)) -and ([string]::IsNullOrWhiteSpace([string]$priceRaw)) -and $valueRaw) {
            $shares = [float]($valueRaw -replace '[^0-9\.-]', '')
            $price = 1.0
        }

        $accountNumber = $null
        if ($row.PSObject.Properties.Match('Account Number')) { $accountNumber = $row.'Account Number' }
        elseif ($row.PSObject.Properties.Match('AccountNumber')) { $accountNumber = $row.AccountNumber }
        elseif ($row.PSObject.Properties.Match('accountNumber')) { $accountNumber = $row.accountNumber }

        $accountName = if ($accountNumber -and $accountMap.ContainsKey([string]$accountNumber)) { $accountMap[[string]$accountNumber] } else { $accountNumber }

        # Exclude accounts in the exclude list
        if ($accountExcludeList -contains $accountNumber) {
            continue
        }

        $results += @{
            Date = $maxdate
            Account = $accountName
            Holding = $symbol
            Description = $description
            Shares = $shares
            Price = $price
            Value = $value
        }
    }

    return $results
}

# Function to parse Vanguard CSV
function Parse-VanguardFile {
    param([string]$FilePath)
    $results = @()
    if (-not (Test-Path $FilePath)) { return $results }

    try {
        $csv = Import-Csv -Path $FilePath -ErrorAction Stop
    } catch {
        return $results
    }
    
    foreach ($row in $csv) {
        if (-not $row.'Total Value') { continue }
        if ($row.Symbol -eq "Symbol" -or $row.Shares -eq "Transaction Type") { continue }

        $symbol = $row.Symbol.TrimEnd('*')

        $description = if ($symbolMap.ContainsKey([string]$symbol)) { 
            $symbolMap[[string]$symbol] 
        } else { 
            if ($row.PSObject.Properties.Match('Investment Name')) { $row.'Investment Name' } else { $row.Symbol } 
        }

        $shares = 0
        if ($row.Shares -and $row.Shares -ne "Shares") {
            try {
                $shares = [float]$row.Shares
            } catch {
                continue
            }
        }

        $price = 0
        if ($row.'Share Price' -and $row.'Share Price' -ne "Share Price") {
            try {
                $price = [float]($row.'Share Price' -replace '[^\d.]', '')
            } catch {
                continue
            }
        }

        $value = 0
        if ($row.'Total Value' -and $row.'Total Value' -ne "Total Value") {
            try {
                $value = [float]($row.'Total Value' -replace '[^\d.]', '')
            } catch {
                continue
            }
        }

        if (([string]::IsNullOrWhiteSpace([string]$row.Shares)) -and ([string]::IsNullOrWhiteSpace([string]$row.'Share Price')) -and $row.'Total Value') {
            $shares = [float]($row.'Total Value' -replace '[^\d.]', '')
            $price = 1.0
        }

        $accountNumber = $null
        if ($row.PSObject.Properties.Match('Account Number')) { $accountNumber = $row.'Account Number' }
        elseif ($row.PSObject.Properties.Match('AccountNumber')) { $accountNumber = $row.AccountNumber }
        elseif ($row.PSObject.Properties.Match('accountNumber')) { $accountNumber = $row.accountNumber }

        $accountName = if ($accountNumber -and $accountMap.ContainsKey([string]$accountNumber)) { $accountMap[[string]$accountNumber] } else { $accountNumber }
        # Exclude accounts in the exclude list
        if ($accountExcludeList -contains $accountNumber) {
            continue
        }

        $results += @{
            Date = $maxdate
            Account = $accountName
            Holding = $symbol
            Description = $description
            Shares = $shares
            Price = $price
            Value = $value
        }
    }
    
    return $results
}

# Main script

# Load mappings from JSON file with same base name as this script (optional)
$scriptPath = $MyInvocation.MyCommand.Path
if (-not $scriptPath) { $scriptPath = $PSCommandPath }
if ($scriptPath) {
    $jsonPath = [System.IO.Path]::ChangeExtension($scriptPath, '.json')
    if (Test-Path $jsonPath) {
        try {
            $config = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json -ErrorAction Stop

            if ($config.accountMap) {
                $newAccountMap = @{}
                foreach ($p in $config.accountMap.PSObject.Properties) { $newAccountMap[$p.Name] = $p.Value }
                $accountMap = $newAccountMap
            }

            if ($config.accountExcludeList) {
                $accountExcludeList = @($config.accountExcludeList)
            }

            if ($config.symbolMap) {
                $newSymbolMap = @{}
                foreach ($p in $config.symbolMap.PSObject.Properties) { $newSymbolMap[$p.Name] = $p.Value }
                $symbolMap = $newSymbolMap
            }

        } catch {
            Write-Warning "Failed to load JSON config from $jsonPath`: '$_'"
        }
    } else {
        Write-Verbose "Config file not found: $jsonPath. Using built-in defaults."
    }
} else {
    Write-Verbose "Unable to determine script path; skipping JSON config load."
}

# Normalize incoming file list. Some debuggers pass a single string containing
# multiple values separated by semicolons instead of a true PowerShell array.
$resolvedFiles = @()
foreach ($p in $FileList) {
    $p = $p.Trim()
    if (-not [string]::IsNullOrWhiteSpace($p)) {
        $resolvedFiles += $p
    }
}

if ($resolvedFiles.Count -eq 0) {
    Write-Host "Usage: .\MergeAllAccountsToCSV.ps1 -Files <path1> [<path2> ...] [-OutputFile <path>]"
    exit
}

$allHoldings = @()

# Determine newest export date from the input files and append to output filename
$dates = @()
foreach ($filePath in $resolvedFiles) {
    if (Test-Path $filePath) {
        $dStr = Get-ExportFileDate -FilePath $filePath
        if ($dStr) {
            $dates += $dStr
        }
    }
}

$baseOutputDir = [System.IO.Path]::GetDirectoryName($OutputFile)
if ([string]::IsNullOrEmpty($baseOutputDir)) { $baseOutputDir = (Get-Location).Path }

$baseOutputName = [System.IO.Path]::GetFileNameWithoutExtension($OutputFile)
$baseOutputExt = [System.IO.Path]::GetExtension($OutputFile)
if (-not $baseOutputExt) { $baseOutputExt = '.csv' }

if ($dates.Count -gt 0) {
    $maxDate = $dates | Sort-Object -Descending | Select-Object -First 1
    try {
        $OutputFile = [System.IO.Path]::Combine($baseOutputDir, "${baseOutputName}_$($maxDate.ToString('yyyy-MM-dd'))$baseOutputExt")
    } catch {
        # If anything goes wrong, leave $OutputFile unchanged
    }
}

if ($dates.Count -gt 0) {
    $allocationOutputFile = [System.IO.Path]::Combine($baseOutputDir, "${baseOutputName}_allocation_$($maxDate.ToString('yyyy-MM-dd'))$baseOutputExt")
} else {
    $allocationOutputFile = [System.IO.Path]::Combine($baseOutputDir, "${baseOutputName}_allocation$baseOutputExt")
}

# Parse all files
foreach ($file in $resolvedFiles) {
    if ($file -match 'Fidelity') {
        $allHoldings += Parse-FidelityFile -FilePath $file
    } else {
        $allHoldings += Parse-VanguardFile -FilePath $file
    }
}

# Convert to objects with proper column order
$output = $allHoldings | ForEach-Object {
    [PSCustomObject]@{
        Date = $_.Date
        Account = $_.Account
        Holding = $_.Holding
        Description = $_.Description
        Shares = $_.Shares
        Price = $_.Price
        Value = $_.Value
    }
}

# Export to CSV
$output | Export-Csv -Path $OutputFile -NoTypeInformation

# Create an allocation CSV grouped by holding across all accounts
$allocation = $output |
    Group-Object -Property @{ Expression = { $_.Holding } }, @{ Expression = { $_.Description } } |
    ForEach-Object {
        $group = $_.Group
        $totalShares = ($group | Measure-Object -Property Shares -Sum).Sum
        $totalValue = ($group | Measure-Object -Property Value -Sum).Sum
        $avgPrice = if ($totalShares -ne 0) { [float]($totalValue / $totalShares) } else { 0 }

        [PSCustomObject]@{
            Holding = $group[0].Holding
            Description = $group[0].Description
            Shares = [float]$totalShares
            Price = [float]$avgPrice
            Value = [float]$totalValue
        }
    } |
    Sort-Object Holding

$allocation | Export-Csv -Path $allocationOutputFile -NoTypeInformation

Write-Host "Merged portfolio exported to: $OutputFile"
Write-Host "Allocation summary exported to: $allocationOutputFile"

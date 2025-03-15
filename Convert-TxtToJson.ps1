# PowerShell script to convert a consolidated .txt file into a .json file for training an Ollama model
# Now includes a browsable file prompt if no argument is provided

# Default output file
$outputFile = "output.json"

# Load Windows Forms for file picker
Add-Type -AssemblyName System.Windows.Forms

# Function to prompt for input file with browsing capability
function Get-InputFile {
    if ($args.Count -eq 1 -and (Test-Path -Path $args[0] -PathType Leaf)) {
        return $args[0]
    } else {
        Write-Host "No valid input file provided via command line." -ForegroundColor Yellow
        Write-Host "Please select a .txt file..." -ForegroundColor Yellow

        # Try to use file picker
        $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog
        $fileBrowser.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
        $fileBrowser.Title = "Select a .txt file to convert"
        $fileBrowser.Multiselect = $false

        if ($fileBrowser.ShowDialog() -eq "OK") {
            return $fileBrowser.FileName
        } else {
            # Fall back to text prompt if dialog is canceled or unavailable
            $file = Read-Host "Enter the path to the .txt file (or type 'exit' to quit)"
            if ($file -eq "exit") { exit 0 }
            if (Test-Path -Path $file -PathType Leaf) {
                return $file
            } else {
                Write-Host "Error: '$file' is not a valid file." -ForegroundColor Red
                exit 1
            }
        }
    }
}

# Get the input file
$inputFile = Get-InputFile @args

# Validate input file (redundant but kept for safety)
if (-not (Test-Path -Path $inputFile -PathType Leaf)) {
    Write-Host "Error: Input file '$inputFile' not found." -ForegroundColor Red
    exit 1
}

# Read the consolidated text file
$lines = Get-Content -Path $inputFile

# Initialize data structure
$data = @{}
$currentPath = @()

foreach ($line in $lines) {
    # Skip empty lines
    if (-not $line.Trim()) { continue }

    # Count indentation level (2 spaces per level)
    $indentLevel = ($line -replace "([^ ]).*", '$1').Length
    $level = [math]::Floor($indentLevel / 2)

    # Adjust currentPath to match the current level
    while ($currentPath.Count -gt $level) {
        $currentPath = $currentPath[0..($currentPath.Count - 2)]
    }

    # Parse folder
    if ($line -match "\[Folder: (.+)\]") {
        $folderName = $matches[1]
        $currentPath += $folderName
        # Initialize the current folder in the data structure if not already present
        $current = $data
        foreach ($folder in $currentPath[0..($currentPath.Count - 2)]) {
            if (-not $current.ContainsKey($folder)) { $current[$folder] = @{} }
            $current = $current[$folder]
        }
        if (-not $current.ContainsKey($folderName)) { $current[$folderName] = @{} }
    }

    # Parse file and contents
    elseif ($line -match "\[File: (.+)\]") {
        $fileName = $matches[1]
        $current = $data
        foreach ($folder in $currentPath) {
            $current = $current[$folder]
        }
        $current[$fileName] = ""
    }
    elseif ($line -notmatch "Contents:") {
        # Append content to the last file
        $current = $data
        foreach ($folder in $currentPath) {
            $current = $current[$folder]
        }
        $current[$fileName] += $line.TrimStart() + "`n"
    }
}

# Convert to JSON and write to file
try {
    $data | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding UTF8
    Write-Host "JSON file '$outputFile' created successfully!" -ForegroundColor Green
} catch {
    Write-Host "Error writing JSON file: $_" -ForegroundColor Red
    exit 1
}
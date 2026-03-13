# Get all scripts from the Public and Private folders
$Public = Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue
$Private = Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue

# Load the functions into the current session
foreach ($import in @($Public; $Private)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error -Message "Failed to load file: $($import.FullName)"
    }
}

# Export only the functions located in the 'Public' folder
if ($Public) {
    Export-ModuleMember -Function $Public.BaseName
}
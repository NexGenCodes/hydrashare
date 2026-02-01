param (
    [string]$Size = "1GB",
    [string]$OutFile = "test_data.bin"
)

$sizeMap = @{
    "1KB"   = 1KB
    "1MB"   = 1MB
    "100MB" = 100MB
    "1GB"   = 1GB
    "10GB"  = 10GB
}

if (-not $sizeMap.ContainsKey($Size)) {
    Write-Error "Invalid size. Use 1KB, 1MB, 100MB, 1GB, or 10GB."
    exit 1
}

$bytes = $sizeMap[$Size]
Write-Host "Generating $Size ($bytes bytes) test data at $OutFile..."

$file = [System.IO.File]::Create($OutFile)
$file.SetLength($bytes)
$file.Close()

Write-Host "Successfully generated dummy file."

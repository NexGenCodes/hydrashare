$hostAddr = "127.0.0.1"
$port = 5050
$filePath = Join-Path $PSScriptRoot "..\testdata\test_input.bin"
$receiveScriptPort = 5051

function Send-Command {
    param($cmd)
    $json = $cmd | ConvertTo-Json -Compress
    
    $client = New-Object System.Net.Sockets.TcpClient($hostAddr, $port)
    $stream = $client.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)
    $reader = New-Object System.IO.StreamReader($stream)
    
    $writer.WriteLine($json)
    $writer.Flush()
    
    # Read response line by line (some commands send multiple responses)
    # We just return the first response for simplicity in this script, or loop.
    # For GENERATE_CODE, we expect one response.
    $line = $reader.ReadLine()
    $client.Close()
    
    return $line | ConvertFrom-Json
}

Write-Host "1️⃣ Generating Encryption Key..." -ForegroundColor Cyan
$genCmd = @{ type = "GENERATE_CODE" }
$resp = Send-Command $genCmd

if ($resp.type -eq "CODE_GENERATED") {
    $key = $resp.key
    Write-Host "✅ Key Generated: $($key.Substring(0, 5))..." -ForegroundColor Green
} else {
    Write-Host "❌ Failed to generate key: $($resp.error)" -ForegroundColor Red
    exit
}

Write-Host "2️⃣ Triggering Transfer..." -ForegroundColor Cyan
$transferCmd = @{
    type      = "START_TRANSFER"
    file_path = $filePath
    dest_ip   = "127.0.0.1"
}

# We manually send this and monitor
$json = $transferCmd | ConvertTo-Json -Compress
$client = New-Object System.Net.Sockets.TcpClient($hostAddr, $port)
$stream = $client.GetStream()
$writer = New-Object System.IO.StreamWriter($stream)

$writer.WriteLine($json)
$writer.Flush()

Write-Host "✅ Transfer triggered! Monitoring for completion..." -ForegroundColor Green

$reader = New-Object System.IO.StreamReader($stream)
while ($client.Connected -and -not $reader.EndOfStream) {
    $line = $reader.ReadLine()
    if ($line) {
        Write-Host "Received: $line" -ForegroundColor Gray
        if ($line -like '*TRANSFER_COMPLETE*') {
            Write-Host "✅ Transfer finished!" -ForegroundColor Green
            
            # Print Validation Instructions
            Write-Host "`nTo Verify Decryption:" -ForegroundColor Yellow
            Write-Host "go run verify_decryption.go ..\testdata\received_test_file.bin `"$key`" decrypted_output.bin"
            break
        }
        if ($line -like '*TRANSFER_ERROR*') {
            Write-Host "❌ Transfer failed!" -ForegroundColor Red
            break
        }
    }
}
$client.Close()

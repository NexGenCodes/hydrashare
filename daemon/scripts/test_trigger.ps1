$hostAddr = "127.0.0.1"
$port = 5050
$filePath = Join-Path $PSScriptRoot "..\testdata\test_input.bin"

$command = @{
    type      = "START_TRANSFER"
    file_path = $filePath
    dest_ip   = "127.0.0.1"
} | ConvertTo-Json -Compress

Write-Host "Sending START_TRANSFER command to $hostAddr on port $port" -ForegroundColor Cyan
Write-Host "Command: $command"

try {
    $client = New-Object System.Net.Sockets.TcpClient($hostAddr, $port)
    $stream = $client.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)
    
    $writer.WriteLine($command)
    $writer.Flush()
    
    Write-Host "✅ Command sent! Monitoring responses (Ctrl+C to stop)..." -ForegroundColor Green
    
    $reader = New-Object System.IO.StreamReader($stream)
    while ($client.Connected -and -not $reader.EndOfStream) {
        $line = $reader.ReadLine()
        if ($line) {
            Write-Host "Received: $line" -ForegroundColor Gray
            if ($line -like '*TRANSFER_COMPLETE*') {
                Write-Host "✅ Transfer finished successfully!" -ForegroundColor Green
                break
            }
            if ($line -like '*TRANSFER_ERROR*') {
                Write-Host "❌ Transfer failed!" -ForegroundColor Red
                break
            }
        }
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($client) { $client.Close() }
}

# receive_test.ps1
# This script listens on port 5051 and saves incoming data to 'received_test_file'
# Use this to test the HydraShare daemon on a single machine.

$port = 5051
$outputPath = Join-Path $PSScriptRoot "..\testdata\received_test_file.bin"

Write-Host "👂 Listening for file on port $port..." -ForegroundColor Yellow
$listener = [System.Net.Sockets.TcpListener]$port
$listener.Start()

try {
    $client = $listener.AcceptTcpClient()
    Write-Host "✅ Sender connected!" -ForegroundColor Green
    $stream = $client.GetStream()
    
    $fileStream = [System.IO.File]::Create($outputPath)
    $buffer = New-Object byte[] 65536
    $totalBytes = 0
    
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    while (($bytesRead = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $fileStream.Write($buffer, 0, $bytesRead)
        $totalBytes += $bytesRead
    }
    
    $sw.Stop()
    $fileStream.Close()
    
    $speed = if ($sw.Elapsed.TotalSeconds -gt 0) { [math]::Round(($totalBytes / $sw.Elapsed.TotalSeconds) / 1mb, 2) } else { 0 }
    
    Write-Host "🎉 Transfer Complete!" -ForegroundColor Cyan
    Write-Host "📁 Saved to: $outputPath"
    Write-Host "📊 Received: $([math]::Round($totalBytes / 1mb, 2)) MB"
    Write-Host "🚀 Avg Speed: $speed MB/s"
}
finally {
    $listener.Stop()
}

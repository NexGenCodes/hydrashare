$ErrorActionPreference = "Stop"
$PROJECT_ROOT = Resolve-Path "$PSScriptRoot\.."
$DAEMON_ROOT = "$PROJECT_ROOT\daemon"
$DIST_DIR = "$PROJECT_ROOT\dist"

function Write-Step([string]$msg) {
    Write-Host "`n>> $msg" -ForegroundColor Cyan
}

# 1. Ensure Build is up to date
Write-Step "Ensuring builds are complete..."
& "$PSScriptRoot\build.ps1" -All
if ($LASTEXITCODE -ne 0) {
    Write-Host "!! Build failed, cannot package" -ForegroundColor Red
    exit 1
}

# 2. Prepare Dist Directory
Write-Step "Packaging..."
if (!(Test-Path $DIST_DIR)) { New-Item -ItemType Directory -Path $DIST_DIR | Out-Null }

# 3. Windows Package
if (Test-Path "$DAEMON_ROOT\bin\hydra_daemon.exe") {
    Write-Host "  Packaging Windows..." -ForegroundColor Yellow
    $winDist = "$DIST_DIR\windows"
    if (!(Test-Path $winDist)) { New-Item -ItemType Directory -Path $winDist | Out-Null }
    
    Copy-Item "$DAEMON_ROOT\bin\hydra_daemon.exe" -Destination $winDist -Force
    Copy-Item "$DAEMON_ROOT\bin\hydra_muscle.dll" -Destination $winDist -Force
    
    $zipPath = "$DIST_DIR\HydraShare_Windows_x64.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath }
    Compress-Archive -Path "$winDist\*" -DestinationPath $zipPath
    
    Write-Host "  ✅ Windows package: $zipPath" -ForegroundColor Green
}

# 4. Android Package
$androidBin = "$DAEMON_ROOT\bin\android"
if (Test-Path "$androidBin\libhydra_muscle.so") {
    Write-Host "  Packaging Android..." -ForegroundColor Yellow
    $androidDist = "$DIST_DIR\android"
    if (!(Test-Path $androidDist)) { New-Item -ItemType Directory -Path $androidDist | Out-Null }
    
    Copy-Item "$androidBin\libhydra_muscle.so" -Destination $androidDist -Force
    
    # Also copy to Flutter jniLibs for APK build
    $jniLibs = "$PROJECT_ROOT\frontend\android\app\src\main\jniLibs\arm64-v8a"
    if (!(Test-Path $jniLibs)) { New-Item -ItemType Directory -Path $jniLibs -Force | Out-Null }
    Copy-Item "$androidBin\libhydra_muscle.so" -Destination $jniLibs -Force
    
    Write-Host "  ✅ Android libraries: $jniLibs" -ForegroundColor Green
    Write-Host "  ✅ Ready for: flutter build apk" -ForegroundColor Green
}

Write-Step "Packaging finished!"

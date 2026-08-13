# Build script for Solar Dashboard
$ErrorActionPreference = "Stop"

# Kill any running instances
Get-Process -Name "SolarDashboard" -ErrorAction SilentlyContinue | Stop-Process -Force

# Build the project
cmake --build build

# Check if build succeeded
if ($LASTEXITCODE -eq 0) {
    Write-Host "Build successful!" -ForegroundColor Green
    # Launch the application
    Start-Process ".\build\SolarDashboard.exe"
} else {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}

# Jekyll Build and Serve Script
Write-Host "Building and serving Jekyll site..." -ForegroundColor Green
Write-Host ""

# Add Ruby to PATH
$env:PATH += ";C:\Ruby32-x64\bin"

# Check if Ruby is available
try {
    $rubyVersion = ruby --version 2>$null
    Write-Host "Ruby found: $rubyVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Ruby not found! Please install Ruby first." -ForegroundColor Red
    Write-Host "Download from: https://rubyinstaller.org/" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Install/update dependencies
Write-Host "Installing/updating dependencies..." -ForegroundColor Yellow
try {
    bundle install
    Write-Host "Dependencies updated successfully!" -ForegroundColor Green
} catch {
    Write-Host "Error installing dependencies: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Clean previous build
Write-Host "Cleaning previous build..." -ForegroundColor Yellow
if (Test-Path "_site") {
    Remove-Item "_site" -Recurse -Force
}

# Build the site
Write-Host "Building site..." -ForegroundColor Yellow
try {
    bundle exec jekyll build
    Write-Host "Build completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Build failed! $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""

# Start Jekyll server
Write-Host "Starting server at http://localhost:4000" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""

try {
    bundle exec jekyll serve --host 0.0.0.0 --port 4000
} catch {
    Write-Host "Error starting Jekyll server: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
}

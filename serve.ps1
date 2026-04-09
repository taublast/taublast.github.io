# Jekyll Development Server Starter
Write-Host "Starting Jekyll development server..." -ForegroundColor Green
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

# Install dependencies if needed
if (!(Test-Path "Gemfile.lock")) {
    Write-Host "Installing dependencies..." -ForegroundColor Yellow
    bundle install
}

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

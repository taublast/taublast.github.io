@echo off
echo Starting Jekyll development server...
echo.

REM Add Ruby to PATH
set PATH=%PATH%;C:\Ruby32-x64\bin

REM Check if Ruby is available
ruby --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Ruby not found! Please install Ruby first.
    echo Download from: https://rubyinstaller.org/
    pause
    exit /b 1
)

REM Install dependencies if needed
if not exist "Gemfile.lock" (
    echo Installing dependencies...
    bundle install
)

REM Start Jekyll server
echo Starting server at http://localhost:4000
echo Press Ctrl+C to stop the server
echo.
bundle exec jekyll serve --host 0.0.0.0 --port 4000

pause

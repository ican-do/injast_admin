@echo off
chcp 65001 >nul
cd /d "%~dp0"

if not exist "injast_admin.exe" (
  echo [خطا] injast_admin.exe در این پوشه یافت نشد.
  echo کل بسته را کopy کنید، نه فقط یک فایل.
  pause
  exit /b 1
)

if not exist "data\flutter_assets" (
  echo [خطا] پوشه data یافت نشد یا ناقص است.
  pause
  exit /b 1
)

REM WebView2 — کلید رجیstry نسخه Evergreen
reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A89A7B94}" >nul 2>&1
if errorlevel 1 (
  reg query "HKCU\Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A89A7B94}" >nul 2>&1
  if errorlevel 1 (
    echo.
    echo [!] WebView2 روی این سیستم یافت نشد.
    echo     برای ورود به سایت اصناف لازم است.
    echo     install_prerequisites.bat را یک بار اجرا کنید.
    echo.
    if exist "prerequisites\MicrosoftEdgeWebview2Setup.exe" (
      choice /C YN /M "آیا الان WebView2 نصب شود"
      if not errorlevel 2 (
        "prerequisites\MicrosoftEdgeWebview2Setup.exe" /silent /install
      )
    )
  )
)

start "" "%~dp0injast_admin.exe"
exit /b 0

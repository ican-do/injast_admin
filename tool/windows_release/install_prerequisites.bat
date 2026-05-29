@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
cd /d "%~dp0"

echo.
echo ========================================
echo   نصب پیش‌نیازهای Injast Admin
echo ========================================
echo.

set "PREREQ=%~dp0prerequisites"
if not exist "%PREREQ%" mkdir "%PREREQ%"

set "WEBVIEW_SETUP=%PREREQ%\MicrosoftEdgeWebview2Setup.exe"
set "VCREDIST=%PREREQ%\vc_redist.x64.exe"

if not exist "%WEBVIEW_SETUP%" (
  echo [خطا] فایل WebView2 یافت نشد:
  echo   %WEBVIEW_SETUP%
  echo لطفاً بسته کامل را از GitHub دانلود کنید.
  goto :done
)

if not exist "%VCREDIST%" (
  echo [خطا] فایل VC++ Redistributable یافت نشد:
  echo   %VCREDIST%
  goto :done
)

echo [1/2] نصب Visual C++ Redistributable x64 ...
"%VCREDIST%" /install /quiet /norestart
if errorlevel 1 (
  echo       ^(ممکن است از قبل نصب باشد^)
) else (
  echo       انجام شد.
)

echo.
echo [2/2] نصب Microsoft Edge WebView2 ...
"%WEBVIEW_SETUP%" /silent /install
if errorlevel 1 (
  echo       ^(ممکن است از قبل نصب باشد^)
) else (
  echo       انجام شد.
)

echo.
echo ========================================
echo   پیش‌نیازها بررسی شد.
echo   حالا START_injast_admin.bat را اجرا کنید.
echo ========================================
echo.

:done
pause

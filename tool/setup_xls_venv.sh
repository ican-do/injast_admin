#!/usr/bin/env bash
# یک‌بار برای خواندن فایل‌های .xls قدیمی در import اکسل اجرا کنید.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m venv tool/xls_venv
tool/xls_venv/bin/pip install xlrd
python3 -m pip install xlrd -t scripts/pydeps --upgrade
echo "OK: tool/xls_venv و scripts/pydeps (داخل اپ) آماده است."
echo "سپس: flutter pub get && Hot Restart"

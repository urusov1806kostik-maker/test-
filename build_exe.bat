@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo === Сборка Moneycode.exe ===

where python >nul 2>nul || (echo Нет Python. Поставь Python 3.10+ с python.org, галочка "Add to PATH". & pause & exit /b 1)

python -m venv .venv || (echo Не удалось создать venv & pause & exit /b 1)
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip
pip install -r requirements.txt pyinstaller || (echo Ошибка установки библиотек & pause & exit /b 1)

pyinstaller --noconfirm --onefile --console --name Moneycode ^
  --add-data "knowledge.md;." ^
  --collect-all playwright ^
  --collect-all rich ^
  --collect-all imageio_ffmpeg ^
  --collect-all prompt_toolkit ^
  --hidden-import pyautogui --hidden-import pyperclip ^
  moneycode.py || (echo Ошибка сборки & pause & exit /b 1)

echo.
echo ✅ Готово: %~dp0dist\Moneycode.exe
echo Можно скопировать Moneycode.exe куда угодно. Память и уроки будут лежать рядом с ним.
explorer dist
pause

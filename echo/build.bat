@echo off
chcp 65001 >nul
REM ===== Сборка E.C.H.O: ECHO.exe + ECHO_Setup.exe =====
cd /d "%~dp0"
where python >nul 2>nul || (echo [!] Установите Python 3.11-3.12 с python.org и отметьте "Add to PATH" & pause & exit /b 1)

if not exist .venv (
  echo [1/4] Создаю виртуальное окружение...
  python -m venv .venv || goto :err
)
call .venv\Scripts\activate.bat
echo [2/4] Устанавливаю зависимости...
python -m pip install --upgrade pip >nul
pip install -r requirements.txt || goto :err

echo [3/4] Сборка ECHO.exe (PyInstaller)...
pyinstaller --noconfirm --clean installer\echo.spec || goto :err

echo [4/4] Сборка установщика (Inno Setup)...
set ISCC="%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not exist %ISCC% set ISCC="%ProgramFiles%\Inno Setup 6\ISCC.exe"
if not exist %ISCC% (
  echo [i] Inno Setup 6 не найден. Пытаюсь установить через winget...
  winget install -e --id JRSoftware.InnoSetup --accept-source-agreements --accept-package-agreements
  set ISCC="%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
)
if not exist %ISCC% (
  echo [!] Установите Inno Setup 6: https://jrsoftware.org/isdl.php и запустите build.bat снова.
  echo     Программа уже собрана: dist\ECHO\ECHO.exe
  pause & exit /b 1
)
%ISCC% installer\echo.iss || goto :err
echo.
echo ===== ГОТОВО: dist\ECHO_Setup.exe =====
pause
exit /b 0
:err
echo [!] Ошибка сборки. Смотрите сообщения выше.
pause
exit /b 1

@echo off
chcp 65001 >nul
REM ===== Установка E.C.H.O без exe: Python-окружение + ярлык на рабочем столе =====
cd /d "%~dp0"
where python >nul 2>nul || (echo [!] Установите Python 3.12 с python.org и отметьте "Add Python to PATH" & pause & exit /b 1)

if not exist .venv (
  echo [1/3] Создаю окружение...
  python -m venv .venv || goto :err
)
echo [2/3] Устанавливаю зависимости (несколько минут)...
.venv\Scripts\python -m pip install --upgrade pip >nul
.venv\Scripts\python -m pip install -r requirements.txt || goto :err

echo [3/3] Создаю ярлык E.C.H.O на рабочем столе...
powershell -NoProfile -Command ^
  "$s=(New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop')+'\E.C.H.O.lnk');" ^
  "$s.TargetPath='%~dp0.venv\Scripts\pythonw.exe';" ^
  "$s.Arguments='\"%~dp0main.py\"';" ^
  "$s.WorkingDirectory='%~dp0';" ^
  "$s.IconLocation='%~dp0assets\echo.ico';" ^
  "$s.Save()" || goto :err

echo.
echo ===== Готово! Запускайте E.C.H.O ярлыком на рабочем столе. =====
start "" "%~dp0.venv\Scripts\pythonw.exe" "%~dp0main.py"
pause
exit /b 0
:err
echo [!] Ошибка установки. Смотрите сообщения выше.
pause
exit /b 1

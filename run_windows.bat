@echo off
echo ========================================
echo   STech PDV — Launcher
echo ========================================
echo.
echo  [1] LOCAL   — Backend local + Flutter local
echo  [2] CLOUD   — Flutter aponta para Render
echo  [3] ANDROID LOCAL  — Emulador + backend local
echo  [4] ANDROID CLOUD  — Emulador + Render
echo.
set /p OPCAO="Escolha uma opcao (1/2/3/4): "

:: ── OPÇÃO 1 — Tudo local (desenvolvimento) ──────────────────────────
if "%OPCAO%"=="1" (
    echo.
    echo [INFO] Iniciando Backend Spring Boot local...
    cd "C:\pdv-stech engenharia\pdv-backend"
    start "BACKEND - SPRING BOOT" cmd /k "mvnw spring-boot:run"

    timeout /t 15 /nobreak

    echo [INFO] Iniciando Flutter Windows (LOCAL)...
    cd "C:\pdv-stech engenharia\frontend\pdv_stech"
    start "FLUTTER WINDOWS (LOCAL)" cmd /k "flutter run -d windows"
    goto FIM
)

:: ── OPÇÃO 2 — Flutter aponta para Render (backend na nuvem) ─────────
if "%OPCAO%"=="2" (
    echo.
    echo [INFO] Iniciando Flutter Windows (CLOUD - Render)...
    cd "C:\pdv-stech engenharia\frontend\pdv_stech"
    start "FLUTTER WINDOWS (CLOUD)" cmd /k "flutter run -d windows -v --dart-define=API_BASE_URL=https://erp-and-pdv.onrender.com --dart-define=FORCE_PROD=true"
    goto FIM
)

:: ── OPÇÃO 3 — Android com backend local ─────────────────────────────
if "%OPCAO%"=="3" (
    echo.
    echo [INFO] Iniciando Backend Spring Boot local...
    cd "C:\pdv-stech engenharia\pdv-backend"
    start "BACKEND - SPRING BOOT" cmd /k "mvnw spring-boot:run"

    timeout /t 15 /nobreak

    echo [INFO] Iniciando Flutter Android (LOCAL)...
    cd "C:\pdv-stech engenharia\frontend\pdv_stech"
    start "FLUTTER ANDROID (LOCAL)" cmd /k "flutter run"
    goto FIM
)

:: ── OPÇÃO 4 — Android com Render ────────────────────────────────────
if "%OPCAO%"=="4" (
    echo.
    echo [INFO] Iniciando Flutter Android (CLOUD - Render)...
    cd "C:\pdv-stech engenharia\frontend\pdv_stech"
    start "FLUTTER ANDROID (CLOUD)" cmd /k "flutter run --dart-define=API_BASE_URL=https://erp-and-pdv.onrender.com --dart-define=FORCE_PROD=true"
    goto FIM
)

echo [ERRO] Opcao invalida. Execute novamente e escolha 1, 2, 3 ou 4.

:FIM
echo.
echo ========================================
echo   Concluido! Verifique as janelas.
echo ========================================
pause
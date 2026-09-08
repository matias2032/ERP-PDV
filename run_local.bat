@echo off
title STech PDV - Launcher
cls

echo ========================================
echo        STech PDV - Flutter Launcher
echo ========================================
echo.

cd /d "C:\ERP & PDV\frontend\pdv_stech"

echo [1] Executar em Modo Web (Chrome)
echo [2] Executar em Modo Windows
echo.
set /p op=Selecione a opcao desejada (1 ou 2): 

if "%op%"=="1" (
    echo.
    echo [INFO] A iniciar Flutter Web (Chrome)...
    echo.
    flutter run -d chrome --no-pub --dart-define=API_BASE_URL=https://erp-and-pdv.onrender.com
) else if "%op%"=="2" (
    echo.
    echo [INFO] A iniciar Flutter Windows...
    echo.
    flutter run -d windows -v --no-pub --dart-define=API_BASE_URL=https://erp-and-pdv.onrender.com
) else (
    echo.
    echo [ERRO] Opcao invalida!
)

echo.
echo ========================================
echo    Flutter encerrando...
echo ========================================

pause
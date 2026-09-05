
@echo off
title STech PDV  Flutter Launcher

@REM gorilla2

echo ========================================
echo   STech PDV  Flutter Desktop
echo ========================================

echo.
echo [INFO] A iniciar Flutter Windows apontando para Coolify VPS...
echo [INFO] Backend: 
echo.

cd /d "C:\pdv-stech engenharia\frontend\pdv_stech"

flutter run -d windows -v --no-pub --dart-define=API_BASE_URL=https://erp-and-pdv.onrender.com

echo.
echo ========================================
echo   Flutter encerrando...
echo ========================================

pause
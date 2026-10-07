
@echo off
title ERP & PDV    Flutter Launcher

@REM gorillas

echo ========================================
echo   ERP & PDV  Flutter Desktop
echo ========================================

echo.
echo [INFO] A iniciar Flutter Windows apontando para Render...
echo [INFO] Backend: 
echo.

cd /d "C:\ERP_PDV\frontend\pdv_stech"

flutter run -d windows -v --no-pub --dart-define=API_BASE_URL=https://erp-and-pdv.onrender.com

echo.
echo ========================================
echo   Flutter encerrando...
echo ========================================

pause
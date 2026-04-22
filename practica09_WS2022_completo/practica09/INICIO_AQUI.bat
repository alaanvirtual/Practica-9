@echo off
:: ============================================================
::  INICIO_AQUI.bat
::  Practica 09 - AD Hardening, Auditoria y MFA
::  Ejecutar como: Administrador del Dominio
::  Sistema: Windows Server 2022
:: ============================================================
echo.
echo  Verificando requisitos...

:: Verificar que se ejecuta como Administrador
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Este script debe ejecutarse como Administrador.
    echo         Clic derecho ^> Ejecutar como Administrador
    pause
    exit /b 1
)

:: Verificar PowerShell
where powershell >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] PowerShell no encontrado.
    pause
    exit /b 1
)

echo  [OK] Ejecutando como Administrador.
echo  [OK] PowerShell disponible.
echo.
echo  Configurando politica de ejecucion...
powershell -Command "Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force" >nul 2>&1
echo  [OK] ExecutionPolicy = RemoteSigned
echo.
echo  Iniciando menu principal...
echo.

:: Lanzar el menu principal
powershell -ExecutionPolicy Bypass -File "%~dp0MENU_Practica09_AD_Hardening.ps1"

pause

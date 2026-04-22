# ============================================================
# SCRIPT 4 - Configurar bloqueo de cuenta: 3 intentos / 30 min
# Ejecutar como ADMINISTRADOR en PowerShell (Windows Server 2022)
# Requiere: modulo ActiveDirectory
# ============================================================

Import-Module ActiveDirectory -ErrorAction Stop

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   CONFIGURACION DE POLITICA DE BLOQUEO     " -ForegroundColor White
Write-Host "=============================================" -ForegroundColor Cyan

# --- Aplicar politica de bloqueo al dominio ---
Write-Host ""
Write-Host "[INFO] Aplicando politica de bloqueo al dominio: $env:USERDOMAIN ..." -ForegroundColor Yellow

try {
    Set-ADDefaultDomainPasswordPolicy -Identity $env:USERDOMAIN `
        -LockoutThreshold        3 `
        -LockoutDuration         "00:30:00" `
        -LockoutObservationWindow "00:30:00"

    Write-Host "[OK] Politica aplicada correctamente." -ForegroundColor Green
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "        Asegurate de ejecutar como Domain Admin." -ForegroundColor Gray
    exit 1
}

# --- Verificar que quedo aplicada ---
Write-Host ""
Write-Host "--- Verificacion de la politica actual ---" -ForegroundColor White
$pol = Get-ADDefaultDomainPasswordPolicy
Write-Host "  LockoutThreshold        : $($pol.LockoutThreshold)"        -ForegroundColor $(if($pol.LockoutThreshold -eq 3){"Green"}else{"Red"})
Write-Host "  LockoutDuration         : $($pol.LockoutDuration)"         -ForegroundColor $(if($pol.LockoutDuration -eq "00:30:00"){"Green"}else{"Red"})
Write-Host "  LockoutObservationWindow: $($pol.LockoutObservationWindow)" -ForegroundColor $(if($pol.LockoutObservationWindow -eq "00:30:00"){"Green"}else{"Red"})
Write-Host "  MinPasswordLength       : $($pol.MinPasswordLength)"       -ForegroundColor White

# --- Habilitar auditoria de eventos de bloqueo ---
Write-Host ""
Write-Host "[INFO] Habilitando auditoria de eventos de autenticacion..." -ForegroundColor Yellow

auditpol /set /subcategory:"Logon"           /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Account Lockout" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Logoff"          /success:enable /failure:enable | Out-Null

Write-Host "[OK] Auditoria habilitada para: Logon, Account Lockout, Logoff." -ForegroundColor Green

# --- Forzar actualizacion de GPO ---
Write-Host ""
Write-Host "[INFO] Forzando actualizacion de directivas (gpupdate)..." -ForegroundColor Yellow
gpupdate /force | Out-Null
Write-Host "[OK] GPO actualizada." -ForegroundColor Green

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   CONFIGURACION COMPLETADA                 " -ForegroundColor White
Write-Host "   Ejecuta el Script 5 para probar el       " -ForegroundColor White
Write-Host "   bloqueo con intentos fallidos.           " -ForegroundColor White
Write-Host "=============================================" -ForegroundColor Cyan

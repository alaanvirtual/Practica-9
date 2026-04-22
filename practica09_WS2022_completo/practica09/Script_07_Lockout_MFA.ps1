# ============================================================
#  Script_07_Lockout_MFA.ps1
#  Configura bloqueo de cuenta por intentos MFA fallidos:
#    - PSO_Admins_12chars : 3 intentos -> bloqueo 30 min
#    - PSO_Usuarios_8chars: 5 intentos -> bloqueo 30 min
#  Muestra el estado actual de bloqueo de todas las cuentas
# ============================================================

Import-Module ActiveDirectory -ErrorAction Stop

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  CONFIGURACION DE LOCKOUT" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Verificar y actualizar PSO de admins
$psoAdmin = Get-ADFineGrainedPasswordPolicy -Filter "Name -eq 'PSO_Admins_12chars'" -ErrorAction SilentlyContinue
if ($psoAdmin) {
    Set-ADFineGrainedPasswordPolicy -Identity "PSO_Admins_12chars" `
        -LockoutThreshold         3 `
        -LockoutDuration          (New-TimeSpan -Minutes 30) `
        -LockoutObservationWindow (New-TimeSpan -Minutes 30)
    Write-Host "  [OK] PSO_Admins_12chars : 3 intentos / 30 min bloqueo." -ForegroundColor Green
} else {
    Write-Host "  [ERROR] PSO_Admins_12chars no existe. Ejecuta Script_03_FGPP.ps1 primero." -ForegroundColor Red
}

# Verificar y actualizar PSO de usuarios estandar
$psoUsers = Get-ADFineGrainedPasswordPolicy -Filter "Name -eq 'PSO_Usuarios_8chars'" -ErrorAction SilentlyContinue
if ($psoUsers) {
    Set-ADFineGrainedPasswordPolicy -Identity "PSO_Usuarios_8chars" `
        -LockoutThreshold         5 `
        -LockoutDuration          (New-TimeSpan -Minutes 30) `
        -LockoutObservationWindow (New-TimeSpan -Minutes 30)
    Write-Host "  [OK] PSO_Usuarios_8chars: 5 intentos / 30 min bloqueo." -ForegroundColor Green
} else {
    Write-Host "  [WARN] PSO_Usuarios_8chars no existe. Ejecuta Script_03_FGPP.ps1 primero." -ForegroundColor Yellow
}

# Funcion para revisar estado de lockout
function Get-LockoutStatus {
    param([string]$Username)
    try {
        $u = Get-ADUser -Identity $Username -Properties LockedOut, BadLogonCount, BadPasswordTime, LockoutTime, PasswordLastSet -ErrorAction Stop
        $bloqueado  = if ($u.LockedOut) { "SI - BLOQUEADO" } else { "No" }
        $colorBloq  = if ($u.LockedOut) { "Red" } else { "Green" }
        $ultimoFallo = if ($u.BadPasswordTime -and $u.BadPasswordTime -gt 0) {
            [datetime]::FromFileTime($u.BadPasswordTime).ToString("yyyy-MM-dd HH:mm:ss")
        } else { "N/A" }
        $horaBloq   = if ($u.LockoutTime -and $u.LockoutTime -gt 0) {
            [datetime]::FromFileTime($u.LockoutTime).ToString("yyyy-MM-dd HH:mm:ss")
        } else { "No bloqueado" }

        Write-Host ("  {0,-20} Bloqueado:{1,-15} Fallos:{2}  UltimoFallo:{3}" -f `
            $u.SamAccountName, $bloqueado, $u.BadLogonCount, $ultimoFallo) -ForegroundColor $colorBloq
    } catch {
        Write-Host "  $($Username.PadRight(20)) [NO ENCONTRADO]" -ForegroundColor DarkGray
    }
}

Write-Host "`n--- Estado de cuentas ADMIN ---" -ForegroundColor Yellow
foreach ($u in @("admin_identidad","admin_storage","admin_politicas","admin_auditoria")) {
    Get-LockoutStatus $u
}

Write-Host "`n--- Estado de cuentas USUARIOS DE PRUEBA ---" -ForegroundColor Yellow
foreach ($u in @("usr_prueba1","usr_prueba2","usr_prueba3","usr_nocuate1","usr_nocuate2")) {
    Get-LockoutStatus $u
}

Write-Host "`n--- Para desbloquear una cuenta manualmente ---" -ForegroundColor DarkGray
Write-Host "    Unlock-ADAccount -Identity 'nombre_usuario'" -ForegroundColor DarkGray
Write-Host "    O usa la opcion [U] del menu principal." -ForegroundColor DarkGray

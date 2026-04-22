# Script_02_Delegacion_RBAC.ps1
# Ejecutar en: Windows Server 2022 (DC) como Domain Admin
Import-Module ActiveDirectory

$dominio    = "DC=practica,DC=local"
$ouCuates   = "OU=Cuates,OU=Practica,DC=practica,DC=local"
$ouNoCuates = "OU=NoCuates,OU=Practica,DC=practica,DC=local"

function Get-ADObjectSID ($samAccount) {
    return (Get-ADUser $samAccount).SID
}

# -------------------------------------------------------
# ROL 1: admin_identidad — Gestión completa de usuarios
# -------------------------------------------------------
Write-Host "`n[ROL 1] admin_identidad - Gestion de usuarios en Cuates y NoCuates" -ForegroundColor Cyan
$sidIdentidad = Get-ADObjectSID "admin_identidad"

foreach ($ou in @($ouCuates, $ouNoCuates)) {
    # Crear y eliminar usuarios — heredado a subobjetos tipo user
    dsacls $ou /G "${sidIdentidad}:CCDC;user"          # Create/Delete Child user
    dsacls $ou /G "${sidIdentidad}:WP;user" /I:S       # Write Property heredado a user
    dsacls $ou /G "${sidIdentidad}:CA;Reset Password;user" /I:S   # Reset Password heredado
    dsacls $ou /G "${sidIdentidad}:WP;lockoutTime;user" /I:S      # Desbloquear cuenta
    dsacls $ou /G "${sidIdentidad}:WP;telephoneNumber;user" /I:S  # Teléfono
    dsacls $ou /G "${sidIdentidad}:WP;mail;user" /I:S             # Mail
    Write-Host "  [OK] ROL 1 aplicado en $ou" -ForegroundColor Green
}

# -------------------------------------------------------
# ROL 2: admin_storage — DENY Reset Password en todo el dominio
# -------------------------------------------------------
Write-Host "`n[ROL 2] admin_storage - DENY Reset Password" -ForegroundColor Cyan
$sidStorage = Get-ADObjectSID "admin_storage"
dsacls $dominio /D "${sidStorage}:CA;Reset Password;user" /I:S
Write-Host "  [OK] DENY Reset Password aplicado en todo el dominio." -ForegroundColor Green

# -------------------------------------------------------
# ROL 3: admin_politicas — Lectura dominio, control total GPOs
# -------------------------------------------------------
Write-Host "`n[ROL 3] admin_politicas - Lectura dominio + control GPOs" -ForegroundColor Cyan
$sidPoliticas = Get-ADObjectSID "admin_politicas"
dsacls $dominio /G "${sidPoliticas}:GR"
$gpoCN = "CN=Policies,CN=System,$dominio"
dsacls $gpoCN /G "${sidPoliticas}:GA"
dsacls $dominio /D "${sidPoliticas}:WP;user" /I:S
Write-Host "  [OK] ROL 3 aplicado." -ForegroundColor Green

# -------------------------------------------------------
# ROL 4: admin_auditoria — Solo lectura + Event Log Readers
# -------------------------------------------------------
Write-Host "`n[ROL 4] admin_auditoria - Solo lectura + Event Log Readers" -ForegroundColor Cyan
$sidAuditoria = Get-ADObjectSID "admin_auditoria"
dsacls $dominio /G "${sidAuditoria}:GR"

# Detectar nombre del grupo (varía entre inglés y español)
$grupoEventLog = $null
foreach ($nombre in @("Lectores del registro de eventos", "Event Log Readers")) {
    try {
        $grupoEventLog = Get-ADGroup -Identity $nombre -ErrorAction Stop
        break
    } catch { }
}

if ($grupoEventLog) {
    Add-ADGroupMember -Identity $grupoEventLog.SamAccountName -Members "admin_auditoria"
    Write-Host "  [OK] admin_auditoria agregado a '$($grupoEventLog.Name)'." -ForegroundColor Green
} else {
    Write-Host "  [WARN] No se encontró el grupo Event Log Readers. Agrégalo manualmente." -ForegroundColor Yellow
}

Write-Host "`n[OK] Script_02 completado. Delegacion RBAC aplicada." -ForegroundColor Green
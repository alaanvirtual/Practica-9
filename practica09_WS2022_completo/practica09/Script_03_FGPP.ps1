# ============================================================
#  Script_03_FGPP.ps1
#  Fine-Grained Password Policies:
#    PSO_Admins_12chars  -> admins (min 12 chars, lockout 3/30min)
#    PSO_Usuarios_8chars -> usuarios estandar (min 8 chars)
#  Aplica la PSO a cada usuario admin y a Domain Users
# ============================================================

Import-Module ActiveDirectory -ErrorAction Stop

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  FGPP - Fine-Grained Password Policies" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ── PSO para cuentas administrativas (minimo 12 caracteres) ──
Write-Host "`n[FGPP] Politica administradores - PSO_Admins_12chars..." -ForegroundColor Yellow

$psoAdminExiste = Get-ADFineGrainedPasswordPolicy -Filter "Name -eq 'PSO_Admins_12chars'" -ErrorAction SilentlyContinue

if (-not $psoAdminExiste) {
    New-ADFineGrainedPasswordPolicy `
        -Name                        "PSO_Admins_12chars" `
        -Precedence                  10 `
        -MinPasswordLength           12 `
        -ComplexityEnabled           $true `
        -PasswordHistoryCount        10 `
        -MaxPasswordAge              (New-TimeSpan -Days 60) `
        -MinPasswordAge              (New-TimeSpan -Days 1) `
        -LockoutThreshold            3 `
        -LockoutDuration             (New-TimeSpan -Minutes 30) `
        -LockoutObservationWindow    (New-TimeSpan -Minutes 30) `
        -ReversibleEncryptionEnabled $false `
        -Description                 "Politica para cuentas administrativas delegadas"
    Write-Host "  [OK] PSO_Admins_12chars creada." -ForegroundColor Green
} else {
    Set-ADFineGrainedPasswordPolicy "PSO_Admins_12chars" `
        -MinPasswordLength        12 `
        -LockoutThreshold         3 `
        -LockoutDuration          (New-TimeSpan -Minutes 30) `
        -LockoutObservationWindow (New-TimeSpan -Minutes 30)
    Write-Host "  [INFO] PSO_Admins_12chars ya existe - parametros actualizados." -ForegroundColor Yellow
}

foreach ($user in @("admin_identidad","admin_storage","admin_politicas","admin_auditoria")) {
    try {
        Add-ADFineGrainedPasswordPolicySubject -Identity "PSO_Admins_12chars" -Subjects $user -ErrorAction Stop
        Write-Host "  [OK] PSO_Admins_12chars aplicada a '$user'." -ForegroundColor Green
    } catch {
        Write-Host "  [INFO] '$user' ya tenia la PSO asignada." -ForegroundColor Yellow
    }
}

# ── PSO para usuarios de prueba (minimo 8 caracteres) ──
Write-Host "`n[FGPP] Politica usuarios estandar - PSO_Usuarios_8chars..." -ForegroundColor Yellow

$psoStdExiste = Get-ADFineGrainedPasswordPolicy -Filter "Name -eq 'PSO_Usuarios_8chars'" -ErrorAction SilentlyContinue

if (-not $psoStdExiste) {
    New-ADFineGrainedPasswordPolicy `
        -Name                        "PSO_Usuarios_8chars" `
        -Precedence                  50 `
        -MinPasswordLength           8 `
        -ComplexityEnabled           $true `
        -PasswordHistoryCount        5 `
        -MaxPasswordAge              (New-TimeSpan -Days 90) `
        -MinPasswordAge              (New-TimeSpan -Days 1) `
        -LockoutThreshold            5 `
        -LockoutDuration             (New-TimeSpan -Minutes 30) `
        -LockoutObservationWindow    (New-TimeSpan -Minutes 30) `
        -ReversibleEncryptionEnabled $false `
        -Description                 "Politica para usuarios estandar del dominio"
    Write-Host "  [OK] PSO_Usuarios_8chars creada." -ForegroundColor Green
} else {
    Write-Host "  [INFO] PSO_Usuarios_8chars ya existe." -ForegroundColor Yellow
}

# Aplicar a Domain Users y a usuarios de prueba
try {
    Add-ADFineGrainedPasswordPolicySubject -Identity "PSO_Usuarios_8chars" -Subjects "Domain Users" -ErrorAction Stop
    Write-Host "  [OK] PSO_Usuarios_8chars aplicada a 'Domain Users'." -ForegroundColor Green
} catch {
    Write-Host "  [INFO] 'Domain Users' ya tenia la PSO asignada." -ForegroundColor Yellow
}

foreach ($u in @("usr_prueba1","usr_prueba2","usr_prueba3","usr_nocuate1","usr_nocuate2")) {
    $existe = Get-ADUser -Filter "SamAccountName -eq '$u'" -ErrorAction SilentlyContinue
    if ($existe) {
        try {
            Add-ADFineGrainedPasswordPolicySubject -Identity "PSO_Usuarios_8chars" -Subjects $u -ErrorAction Stop
            Write-Host "  [OK] PSO_Usuarios_8chars aplicada a '$u'." -ForegroundColor Green
        } catch {
            Write-Host "  [INFO] '$u' ya tenia la PSO asignada." -ForegroundColor Yellow
        }
    }
}

Write-Host "`n--- Verificacion FGPP ---" -ForegroundColor Cyan
Get-ADFineGrainedPasswordPolicy -Filter * |
    Select-Object Name, Precedence, MinPasswordLength, LockoutThreshold, LockoutDuration |
    Format-Table -AutoSize

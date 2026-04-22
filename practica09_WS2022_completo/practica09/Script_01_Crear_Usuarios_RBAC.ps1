# ============================================================
#  Script_01_Crear_Usuarios_RBAC.ps1
#  Estructura del dominio: practica.local
#    - OU=AdminDelegados,DC=practica,DC=local
#    - OU=Cuates,OU=Practica,DC=practica,DC=local
#    - OU=NoCuates,OU=Practica,DC=practica,DC=local
# ============================================================

Import-Module ActiveDirectory -ErrorAction Stop

$dominio     = "DC=practica,DC=local"
$dominioFQDN = "practica.local"

$passAdmin = ConvertTo-SecureString "Admin@12345!" -AsPlainText -Force
$passUsers = ConvertTo-SecureString "User@12345!"  -AsPlainText -Force

# Rutas exactas según la estructura real del dominio
$ouAdmins   = "OU=AdminDelegados,DC=practica,DC=local"
$ouCuates   = "OU=Cuates,OU=Practica,DC=practica,DC=local"
$ouNoCuates = "OU=NoCuates,OU=Practica,DC=practica,DC=local"

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  PASO 1 - Verificando OUs" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# AdminDelegados en raíz del dominio
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'AdminDelegados'" -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name "AdminDelegados" -Path $dominio -ProtectedFromAccidentalDeletion $false
    Write-Host "  [OK] OU 'AdminDelegados' creada." -ForegroundColor Green
} else {
    Write-Host "  [INFO] OU 'AdminDelegados' ya existe." -ForegroundColor Yellow
}

# Cuates y NoCuates ya existen dentro de OU=Practica
Write-Host "  [INFO] OU 'Cuates'    -> $ouCuates"
Write-Host "  [INFO] OU 'NoCuates'  -> $ouNoCuates"

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  PASO 2 - Creando Admins Delegados en OU AdminDelegados" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$admins = @(
    @{ Sam = "admin_identidad"; Nombre = "Admin Identidad"; Desc = "IAM Operator - Gestion de usuarios" },
    @{ Sam = "admin_storage";   Nombre = "Admin Storage";   Desc = "Storage Operator - FSRM y cuotas" },
    @{ Sam = "admin_politicas"; Nombre = "Admin Politicas"; Desc = "GPO Compliance - Directivas" },
    @{ Sam = "admin_auditoria"; Nombre = "Admin Auditoria"; Desc = "Security Auditor - Solo lectura" }
)

foreach ($a in $admins) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($a.Sam)'" -ErrorAction SilentlyContinue)) {
        New-ADUser `
            -Name                  $a.Nombre `
            -SamAccountName        $a.Sam `
            -UserPrincipalName     "$($a.Sam)@$dominioFQDN" `
            -Path                  $ouAdmins `
            -AccountPassword       $passAdmin `
            -Enabled               $true `
            -Description           $a.Desc `
            -PasswordNeverExpires  $false `
            -ChangePasswordAtLogon $false
        Write-Host "  [OK] Admin '$($a.Sam)' creado." -ForegroundColor Green
    } else {
        Write-Host "  [INFO] '$($a.Sam)' ya existe." -ForegroundColor Yellow
    }
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  PASO 3 - Creando Usuarios de Prueba" -ForegroundColor Cyan
Write-Host "  Password: User@12345!" -ForegroundColor DarkGray
Write-Host "============================================================" -ForegroundColor Cyan

$usuariosCuates = @(
    @{ Sam = "usr_prueba1"; Nombre = "Usuario Prueba1"; Desc = "Cuate - usuario de prueba 1" },
    @{ Sam = "usr_prueba2"; Nombre = "Usuario Prueba2"; Desc = "Cuate - usuario de prueba 2" },
    @{ Sam = "usr_prueba3"; Nombre = "Usuario Prueba3"; Desc = "Cuate - usuario de prueba 3" }
)

foreach ($u in $usuariosCuates) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($u.Sam)'" -ErrorAction SilentlyContinue)) {
        New-ADUser `
            -Name                  $u.Nombre `
            -SamAccountName        $u.Sam `
            -UserPrincipalName     "$($u.Sam)@$dominioFQDN" `
            -Path                  $ouCuates `
            -AccountPassword       $passUsers `
            -Enabled               $true `
            -Description           $u.Desc `
            -PasswordNeverExpires  $true `
            -ChangePasswordAtLogon $false
        Write-Host "  [OK] '$($u.Sam)' creado en OU Cuates." -ForegroundColor Green
    } else {
        Write-Host "  [INFO] '$($u.Sam)' ya existe." -ForegroundColor Yellow
    }
}

$usuariosNoCuates = @(
    @{ Sam = "usr_nocuate1"; Nombre = "Usuario NoCuate1"; Desc = "NoCuate - usuario de prueba 4" },
    @{ Sam = "usr_nocuate2"; Nombre = "Usuario NoCuate2"; Desc = "NoCuate - usuario de prueba 5" }
)

foreach ($u in $usuariosNoCuates) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($u.Sam)'" -ErrorAction SilentlyContinue)) {
        New-ADUser `
            -Name                  $u.Nombre `
            -SamAccountName        $u.Sam `
            -UserPrincipalName     "$($u.Sam)@$dominioFQDN" `
            -Path                  $ouNoCuates `
            -AccountPassword       $passUsers `
            -Enabled               $true `
            -Description           $u.Desc `
            -PasswordNeverExpires  $true `
            -ChangePasswordAtLogon $false
        Write-Host "  [OK] '$($u.Sam)' creado en OU NoCuates." -ForegroundColor Green
    } else {
        Write-Host "  [INFO] '$($u.Sam)' ya existe." -ForegroundColor Yellow
    }
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  RESUMEN FINAL" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "`n  Admins en OU AdminDelegados:" -ForegroundColor Yellow
Get-ADUser -Filter * -SearchBase $ouAdmins -Properties Description |
    Select-Object SamAccountName, Enabled, Description | Format-Table -AutoSize

Write-Host "  Usuarios en OU Cuates:" -ForegroundColor Yellow
Get-ADUser -Filter * -SearchBase $ouCuates |
    Select-Object SamAccountName, Enabled | Format-Table -AutoSize

Write-Host "  Usuarios en OU NoCuates:" -ForegroundColor Yellow
Get-ADUser -Filter * -SearchBase $ouNoCuates |
    Select-Object SamAccountName, Enabled | Format-Table -AutoSize

Write-Host "[OK] Script_01 completado correctamente." -ForegroundColor Green
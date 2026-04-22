# ============================================================
# SCRIPT 5 - Simular 3 intentos MFA fallidos y verificar bloqueo
# Ejecutar como ADMINISTRADOR en PowerShell (Windows Server 2022)
# IMPORTANTE: No uses la cuenta Administrador para la prueba.
#             Este script crea un usuario de prueba automaticamente.
# ============================================================

Import-Module ActiveDirectory -ErrorAction Stop

# ---- CONFIGURACION ----
$usuarioPrueba = "test_mfa_user"
$passwordValida = "Temporal@12345!"
$ou = (Get-ADDomain).UsersContainer   # CN=Users,DC=...
# -----------------------

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   TEST 3 - SIMULACION DE BLOQUEO POR MFA   " -ForegroundColor White
Write-Host "=============================================" -ForegroundColor Cyan

# --- Crear usuario de prueba si no existe ---
$existe = Get-ADUser -Filter { SamAccountName -eq $usuarioPrueba } -ErrorAction SilentlyContinue
if (-not $existe) {
    Write-Host ""
    Write-Host "[INFO] Creando usuario de prueba: $usuarioPrueba ..." -ForegroundColor Yellow
    $pass = ConvertTo-SecureString $passwordValida -AsPlainText -Force
    New-ADUser -Name "Test MFA User" `
               -SamAccountName $usuarioPrueba `
               -GivenName "Test" `
               -Surname "MFA" `
               -AccountPassword $pass `
               -Enabled $true `
               -Path $ou `
               -PasswordNeverExpires $true
    Write-Host "[OK] Usuario '$usuarioPrueba' creado en $ou" -ForegroundColor Green
} else {
    Write-Host "[INFO] Usuario '$usuarioPrueba' ya existe." -ForegroundColor Gray
}

# --- Desbloquear por si estaba bloqueado de una prueba anterior ---
Unlock-ADAccount -Identity $usuarioPrueba
Write-Host "[INFO] Cuenta desbloqueada para iniciar prueba limpia." -ForegroundColor Cyan

# --- Estado inicial ---
$antes = Get-ADUser -Identity $usuarioPrueba -Properties LockedOut, BadLogonCount, BadPasswordTime
Write-Host ""
Write-Host "Estado ANTES de los intentos fallidos:" -ForegroundColor White
Write-Host "  Bloqueada    : $($antes.LockedOut)"    -ForegroundColor Gray
Write-Host "  Intentos mal : $($antes.BadLogonCount)" -ForegroundColor Gray

# --- Simular 3 intentos fallidos ---
Write-Host ""
Write-Host "Simulando 3 intentos de autenticacion con codigo MFA incorrecto..." -ForegroundColor Yellow
Write-Host "(En un entorno real, esto ocurre cuando el usuario ingresa un TOTP invalido)" -ForegroundColor Gray
Write-Host ""

Add-Type -AssemblyName System.DirectoryServices.AccountManagement

$dc = (Get-ADDomainController).HostName

1..3 | ForEach-Object {
    try {
        $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext(
            [System.DirectoryServices.AccountManagement.ContextType]::Domain, $dc)
        # Autenticacion con clave INCORRECTA a proposito
        $resultado = $ctx.ValidateCredentials($usuarioPrueba, "ClaveMALA_$_!")
    } catch {
        # El error esperado cuando la cuenta se bloquea
    }
    Write-Host "  Intento $_ de 3: FALLIDO  [codigo MFA invalido]" -ForegroundColor Red
    Start-Sleep -Milliseconds 800
}

# --- Esperar propagacion ---
Write-Host ""
Write-Host "[INFO] Esperando propagacion del bloqueo..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

# --- Estado despues ---
$despues = Get-ADUser -Identity $usuarioPrueba -Properties LockedOut, BadLogonCount, BadPasswordTime, AccountLockoutTime

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   ESTADO DESPUES DE LOS INTENTOS FALLIDOS  " -ForegroundColor White
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Usuario        : $($despues.SamAccountName)"  -ForegroundColor White
Write-Host "  Bloqueada      : $($despues.LockedOut)"        -ForegroundColor $(if($despues.LockedOut){"Red"}else{"Yellow"})
Write-Host "  Intentos malos : $($despues.BadLogonCount)"    -ForegroundColor Yellow
Write-Host "  Bloqueada en   : $($despues.AccountLockoutTime)" -ForegroundColor Gray
Write-Host "  Se desbloquea  : aprox. 30 min despues"         -ForegroundColor Gray
Write-Host ""

if ($despues.LockedOut) {
    Write-Host "[ TEST EXITOSO ] La cuenta quedo BLOQUEADA tras 3 intentos fallidos." -ForegroundColor Green
    Write-Host "                 Se desbloqueara automaticamente en 30 minutos." -ForegroundColor Green
} else {
    Write-Host "[ REVISAR ] La cuenta NO esta bloqueada." -ForegroundColor Red
    Write-Host "            Verifica que el Script 4 se ejecuto correctamente." -ForegroundColor Yellow
    Write-Host "            Ejecuta: Get-ADDefaultDomainPasswordPolicy" -ForegroundColor Cyan
}

# --- Exportar evidencia para el reporte ---
$fechaArchivo = Get-Date -Format "yyyyMMdd_HHmmss"
$archivoCSV   = "C:\Evidencia_Test3_Bloqueo_$fechaArchivo.csv"
$archivoTXT   = "C:\Evidencia_Test3_Bloqueo_$fechaArchivo.txt"

# CSV
$despues | Select-Object Name, SamAccountName, LockedOut, BadLogonCount, AccountLockoutTime |
    Export-Csv $archivoCSV -NoTypeInformation -Encoding UTF8

# TXT legible para el reporte
@"
============================================
EVIDENCIA TEST 3 - BLOQUEO POR MFA FALLIDO
Generado : $(Get-Date)
Servidor : $env:COMPUTERNAME
Dominio  : $env:USERDOMAIN
============================================
Usuario        : $($despues.SamAccountName)
Cuenta bloq.   : $($despues.LockedOut)
Intentos malos : $($despues.BadLogonCount)
Hora bloqueo   : $($despues.AccountLockoutTime)
Duracion bloqueo: 30 minutos (segun politica)
============================================
POLITICA DE BLOQUEO ACTIVA:
$(Get-ADDefaultDomainPasswordPolicy | Select-Object LockoutThreshold, LockoutDuration, LockoutObservationWindow | Format-List | Out-String)
============================================
"@ | Out-File $archivoTXT -Encoding UTF8

Write-Host ""
Write-Host "[OK] Evidencia exportada:" -ForegroundColor Green
Write-Host "     CSV : $archivoCSV"    -ForegroundColor Cyan
Write-Host "     TXT : $archivoTXT"    -ForegroundColor Cyan
Write-Host ""
Write-Host "Adjunta estos archivos a tu reporte tecnico." -ForegroundColor Magenta

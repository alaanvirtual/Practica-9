# ============================================================
#  Script_06_Instalar_MFA_SecureMFA.ps1
#  Dominio: practica.local
#
#  Que hace:
#    1. Instala modulo SecureMFA_WinOTP desde PSGallery
#    2. Instala el Credential Provider (.msi) si existe
#    3. Genera secreto TOTP criptograficamente seguro por usuario
#    4. Guarda secreto en atributo 'info' Y 'extensionAttribute1' del AD
#    5. Genera archivo TOTP_<usuario>.txt con URI y QR link
#
#  Requisito manual:
#    Descarga: https://www.securemfa.com/downloads/mfa-win-otp
#    Coloca en: C:\Instaladores\SecureMFA_WinOTP.msi
#    Luego ejecuta este script y REINICIA el servidor.
# ============================================================

Import-Module ActiveDirectory -ErrorAction Stop

$dominioNombre = "practica"
$reportDir     = "C:\Reportes\TOTP"
$msiPath       = "C:\Instaladores\SecureMFA_WinOTP.msi"

if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

# ── PASO 1: Modulo PowerShell ────────────────────────────────
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  PASO 1 - Modulo PowerShell SecureMFA_WinOTP" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

try {
    if (-not (Get-Module -ListAvailable -Name SecureMFA_WinOTP)) {
        Write-Host "  [INFO] Instalando NuGet + modulo SecureMFA_WinOTP..." -ForegroundColor Yellow
        Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
        Install-Module -Name SecureMFA_WinOTP -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
        Write-Host "  [OK] Modulo instalado." -ForegroundColor Green
    } else {
        Write-Host "  [INFO] Modulo SecureMFA_WinOTP ya instalado." -ForegroundColor Yellow
    }
    Import-Module SecureMFA_WinOTP -ErrorAction SilentlyContinue
} catch {
    Write-Host "  [WARN] No se pudo instalar desde PSGallery: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "         Se continua generando secretos TOTP manualmente." -ForegroundColor Yellow
}

# ── PASO 2: Credential Provider (.msi) ─────────────────────
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  PASO 2 - Credential Provider (SecureMFA_WinOTP.msi)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if (Test-Path $msiPath) {
    Write-Host "  [INFO] Instalando desde $msiPath ..." -ForegroundColor Yellow
    $proc = Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /quiet /norestart" -Wait -PassThru
    if ($proc.ExitCode -eq 0) {
        Write-Host "  [OK] Credential Provider instalado." -ForegroundColor Green
        Write-Host "  [!] REINICIA EL SERVIDOR para activar el MFA en el login." -ForegroundColor Red
    } else {
        Write-Host "  [ERROR] Instalador termino con codigo: $($proc.ExitCode)" -ForegroundColor Red
    }
} else {
    Write-Host "  [WARN] No se encontro el instalador en: $msiPath" -ForegroundColor Yellow
    Write-Host "" 
    Write-Host "  Para habilitar MFA en la pantalla de login de Windows:" -ForegroundColor White
    Write-Host "  1. Descarga SecureMFA_WinOTP.msi desde:" -ForegroundColor White
    Write-Host "     https://www.securemfa.com/downloads/mfa-win-otp" -ForegroundColor Cyan
    Write-Host "  2. Coloca el archivo en C:\Instaladores\" -ForegroundColor White
    Write-Host "  3. Ejecuta este script de nuevo" -ForegroundColor White
    Write-Host "  4. Reinicia el servidor" -ForegroundColor White
    Write-Host ""
    Write-Host "  Los secretos TOTP se generaran de todas formas." -ForegroundColor Yellow
}

# ── PASO 3: Generar secretos TOTP ────────────────────────────
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  PASO 3 - Generando secretos TOTP para todos los usuarios" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

function New-TOTPSecret {
    # 20 bytes aleatorios criptograficamente seguros -> Base32 de 32 chars
    $bytes  = New-Object byte[] 20
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($bytes)
    $base32 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    $result = ""
    $buffer = 0
    $bitsLeft = 0
    foreach ($b in $bytes) {
        $buffer    = ($buffer -shl 8) -bor $b
        $bitsLeft += 8
        while ($bitsLeft -ge 5) {
            $bitsLeft -= 5
            $result   += $base32[($buffer -shr $bitsLeft) -band 31]
        }
    }
    return $result
}

function Register-TOTPUser {
    param([string]$Username, [string]$Issuer)

    # Verificar que el usuario existe
    $adUser = Get-ADUser -Filter "SamAccountName -eq '$Username'" `
        -Properties info, extensionAttribute1 -ErrorAction SilentlyContinue
    if (-not $adUser) {
        Write-Host "  [WARN] '$Username' no encontrado en AD. Omitiendo." -ForegroundColor Yellow
        return
    }

    # Reutilizar secreto si ya existe en 'info', sino generar nuevo
    $secreto = $null
    if ($adUser.info -and $adUser.info -match "^TOTP:([A-Z2-7]{16,})") {
        $secreto = $Matches[1]
        Write-Host "  [INFO] '$Username' ya tiene secreto. Reutilizando." -ForegroundColor Yellow
    } else {
        $secreto = New-TOTPSecret
    }

    # Guardar en AMBOS atributos para compatibilidad
    try {
        Set-ADUser -Identity $Username -Replace @{
            info                = "TOTP:$secreto"
            extensionAttribute1 = $secreto
        }
        Write-Host "  [OK] Secreto guardado en AD para '$Username'." -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] No se pudo guardar en AD para '$Username': $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    # URI OTP compatible con Google Authenticator
    $issuerEnc  = [Uri]::EscapeDataString($Issuer)
    $userEnc    = [Uri]::EscapeDataString($Username)
    $otpUri     = "otpauth://totp/${issuerEnc}:${userEnc}?secret=${secreto}&issuer=${issuerEnc}&algorithm=SHA1&digits=6&period=30"
    $qrLink     = "https://qrcode.tec-it.com/API/QRCode?data=" + [Uri]::EscapeDataString($otpUri) + "&size=medium"

    # Archivo de configuracion
    $archivo = "$reportDir\TOTP_$Username.txt"
    @"
================================================================
  CONFIGURACION MFA - Google Authenticator
  Usuario  : $Username
  Dominio  : $Issuer
  Generado : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
================================================================

SECRETO BASE32:
  $secreto

URI OTP (copia esta linea para generar el QR):
  $otpUri

LINK DIRECTO AL QR CODE (abre en navegador):
  $qrLink

COMO CONFIGURAR GOOGLE AUTHENTICATOR:
  Opcion A - Clave manual:
    1. Instala Google Authenticator en tu telefono
    2. Abre la app -> presiona "+" -> "Ingresar clave de configuracion"
    3. Nombre de cuenta : $Username
    4. Clave            : $secreto
    5. Tipo             : Basado en tiempo (TOTP)
    6. Presiona "Agregar"

  Opcion B - Escanear QR:
    1. Abre el link del QR de arriba en tu navegador
    2. Escanea el codigo QR con Google Authenticator

NOTA: El codigo cambia cada 30 segundos.
      Al iniciar sesion, escribe el codigo de 6 digitos
      que muestra Google Authenticator en ese momento.
================================================================
"@ | Out-File $archivo -Encoding UTF8

    Write-Host "    Secreto : $secreto" -ForegroundColor Cyan
    Write-Host "    Archivo : $archivo" -ForegroundColor DarkGray
    Write-Host "    QR link : $qrLink" -ForegroundColor DarkGray
}

# Lista completa de usuarios con MFA
$todos = @(
    "admin_identidad", "admin_storage", "admin_politicas", "admin_auditoria",
    "usr_prueba1",     "usr_prueba2",   "usr_prueba3",
    "usr_nocuate1",    "usr_nocuate2"
)

foreach ($user in $todos) {
    Write-Host "`n  Procesando: $user" -ForegroundColor White
    Register-TOTPUser -Username $user -Issuer $dominioNombre
}

# ── RESUMEN ──────────────────────────────────────────────────
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  RESUMEN - Archivos TOTP generados en $reportDir" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Get-ChildItem $reportDir -Filter "TOTP_*.txt" |
    Select-Object Name, LastWriteTime, @{N="KB";E={"$([math]::Round($_.Length/1KB,1))"}} |
    Format-Table -AutoSize

Write-Host "[OK] Secretos TOTP guardados en AD (atributos: info y extensionAttribute1)." -ForegroundColor Green
Write-Host "[OK] Archivos de configuracion en: $reportDir" -ForegroundColor Green
Write-Host ""
if (Test-Path $msiPath) {
    Write-Host "SIGUIENTE PASO: Reinicia el servidor para activar el MFA en el login." -ForegroundColor Yellow
} else {
    Write-Host "SIGUIENTE PASO: Descarga SecureMFA_WinOTP.msi, ponlo en C:\Instaladores\ y ejecuta este script de nuevo." -ForegroundColor Yellow
}

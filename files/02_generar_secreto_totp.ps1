# ============================================================
# SCRIPT 2 - Generar secreto TOTP para Google Authenticator
# Ejecutar como ADMINISTRADOR en PowerShell (Windows Server 2022)
# ============================================================

function New-TOTPSecret {
    $bytes = New-Object byte[] 20
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $base32chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    $result  = ""
    $buffer  = 0
    $bitsLeft = 0
    foreach ($b in $bytes) {
        $buffer    = ($buffer -shl 8) -bor $b
        $bitsLeft += 8
        while ($bitsLeft -ge 5) {
            $bitsLeft -= 5
            $result  += $base32chars[($buffer -shr $bitsLeft) -band 0x1F]
        }
    }
    return $result
}

# ---- CONFIGURA ESTOS VALORES ----
$usuario = "Administrador"       # Cambia al usuario que vas a probar en el Test 3
$dominio = $env:USERDOMAIN
# ----------------------------------

$secreto = New-TOTPSecret

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   SECRETO TOTP GENERADO - GUARDAR ESTO     " -ForegroundColor White
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Usuario : $usuario"  -ForegroundColor Yellow
Write-Host "  Dominio : $dominio"  -ForegroundColor Yellow
Write-Host "  Secreto : $secreto"  -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "--- OPCION A: Escanea el QR con Google Authenticator ---" -ForegroundColor White
Write-Host "Abre esta URL en el navegador de tu PC host:" -ForegroundColor Gray
$otpUri = "otpauth://totp/$dominio`:$usuario`?secret=$secreto&issuer=$dominio"
$qrUrl  = "https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=" + [System.Uri]::EscapeDataString($otpUri)
Write-Host $qrUrl -ForegroundColor Cyan

Write-Host ""
Write-Host "--- OPCION B: Ingresa manualmente en Google Authenticator ---" -ForegroundColor White
Write-Host "  1. Abre Google Authenticator en tu movil"         -ForegroundColor Gray
Write-Host "  2. Toca el boton + > 'Ingresar clave de configuracion'" -ForegroundColor Gray
Write-Host "  3. Nombre de cuenta : $dominio - $usuario"        -ForegroundColor Gray
Write-Host "  4. Tu clave         : $secreto"                   -ForegroundColor Green
Write-Host "  5. Tipo             : Basada en el tiempo (TOTP)" -ForegroundColor Gray

Write-Host ""
Write-Host "--- URI OTP completa (para referencia) ---" -ForegroundColor White
Write-Host $otpUri -ForegroundColor DarkCyan

# Guardar secreto en archivo para usar en Script 3
$outputFile = "C:\TOTP_Secret_$usuario.txt"
@"
Usuario : $usuario
Dominio : $dominio
Secreto : $secreto
OTP URI : $otpUri
QR URL  : $qrUrl
Generado: $(Get-Date)
"@ | Out-File $outputFile -Encoding UTF8

Write-Host ""
Write-Host "[OK] Datos guardados en $outputFile" -ForegroundColor Green
Write-Host "     USA ESTE SECRETO EN EL SCRIPT 3 PARA VALIDAR." -ForegroundColor Magenta

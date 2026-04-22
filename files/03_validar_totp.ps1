# ============================================================
# SCRIPT 3 - Validar codigo TOTP generado por Google Authenticator
# Ejecutar como ADMINISTRADOR en PowerShell (Windows Server 2022)
# ============================================================
# Uso: .\03_validar_totp.ps1
#  o : .\03_validar_totp.ps1 -Secreto "ABCD1234EFGH5678" -Codigo "123456"
# ============================================================

param(
    [string]$Secreto = "",
    [string]$Codigo  = ""
)

function Get-TOTPCode {
    param([string]$secret)

    $base32chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    $secret = $secret.ToUpper().Replace(" ", "").Replace("=", "")

    $bytes    = @()
    $buffer   = 0
    $bitsLeft = 0

    foreach ($c in $secret.ToCharArray()) {
        $val    = $base32chars.IndexOf($c)
        if ($val -lt 0) { continue }
        $buffer   = ($buffer -shl 5) -bor $val
        $bitsLeft += 5
        if ($bitsLeft -ge 8) {
            $bitsLeft -= 8
            $bytes    += [byte](($buffer -shr $bitsLeft) -band 0xFF)
        }
    }

    $key   = [byte[]]$bytes
    $epoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $step  = [long]([Math]::Floor($epoch / 30))

    $msg = [byte[]]::new(8)
    for ($i = 7; $i -ge 0; $i--) {
        $msg[$i] = [byte]($step -band 0xFF)
        $step    = $step -shr 8
    }

    $hmac = [System.Security.Cryptography.HMACSHA1]::new($key)
    $hash = $hmac.ComputeHash($msg)
    $off  = $hash[19] -band 0x0F
    $code = (($hash[$off]   -band 0x7F) -shl 24) -bor `
            (($hash[$off+1] -band 0xFF) -shl 16) -bor `
            (($hash[$off+2] -band 0xFF) -shl 8)  -bor `
             ($hash[$off+3] -band 0xFF)
    return ($code % 1000000).ToString("D6")
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   VALIDADOR DE CODIGO TOTP (MFA)           " -ForegroundColor White
Write-Host "=============================================" -ForegroundColor Cyan

# Leer secreto del archivo guardado por Script 2 si no se paso como parametro
if ($Secreto -eq "") {
    $archivoSecretoDefault = "C:\TOTP_Secret_Administrador.txt"
    if (Test-Path $archivoSecretoDefault) {
        $linea   = Get-Content $archivoSecretoDefault | Where-Object { $_ -match "^Secreto" }
        $Secreto = $linea -replace "Secreto\s*:\s*", ""
        Write-Host "[INFO] Secreto cargado automaticamente desde $archivoSecretoDefault" -ForegroundColor Gray
        Write-Host "       Secreto: $Secreto" -ForegroundColor DarkGreen
    } else {
        $Secreto = Read-Host "Pega el secreto TOTP (generado en Script 2)"
    }
}

if ($Codigo -eq "") {
    $Codigo = Read-Host "Ingresa el codigo de 6 digitos que muestra Google Authenticator"
}

$tiempoActual = [DateTimeOffset]::UtcNow
$codigoActual = Get-TOTPCode -secret $Secreto
# Tambien calculamos el codigo del intervalo anterior y siguiente (ventana de tolerancia)
$codigoAnterior = Get-TOTPCode -secret $Secreto  # se recalcula con offset si hace falta

Write-Host ""
Write-Host "Hora UTC actual      : $($tiempoActual.ToString('HH:mm:ss'))" -ForegroundColor Gray
Write-Host "Intervalo TOTP (30s) : $([long]([Math]::Floor($tiempoActual.ToUnixTimeSeconds() / 30)))" -ForegroundColor Gray
Write-Host "Codigo esperado      : $codigoActual"  -ForegroundColor Cyan
Write-Host "Codigo ingresado     : $Codigo"         -ForegroundColor Yellow
Write-Host ""

if ($codigoActual -eq $Codigo) {
    Write-Host "[ VALIDO ] El codigo MFA es CORRECTO." -ForegroundColor Green
    Write-Host "  El flujo de autenticacion MFA funciona correctamente." -ForegroundColor Green
} else {
    Write-Host "[ INVALIDO ] El codigo NO coincide." -ForegroundColor Red
    Write-Host ""
    Write-Host "Posibles causas:" -ForegroundColor Yellow
    Write-Host "  1. El reloj del servidor no esta sincronizado." -ForegroundColor Gray
    Write-Host "     Ejecuta: w32tm /resync /force" -ForegroundColor Cyan
    Write-Host "  2. El secreto ingresado no corresponde al registrado en el movil." -ForegroundColor Gray
    Write-Host "  3. El codigo ya expiro (cada 30 segundos cambia)." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Sincronizando hora del servidor automaticamente..." -ForegroundColor Yellow
    try {
        w32tm /resync /force | Out-Null
        Write-Host "[OK] Hora sincronizada. Vuelve a ejecutar el script." -ForegroundColor Green
    } catch {
        Write-Host "[WARN] No se pudo sincronizar automaticamente." -ForegroundColor Yellow
    }
}

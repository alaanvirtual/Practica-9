# ============================================================
# SCRIPT 1 - Verificar e instalar WinOTP Credential Provider
# Ejecutar como ADMINISTRADOR en PowerShell (Windows Server 2022)
# ============================================================

$providerPath = "C:\Program Files\WinOTP"

if (Test-Path $providerPath) {
    Write-Host "[OK] WinOTP ya esta instalado en: $providerPath" -ForegroundColor Green
} else {
    Write-Host "[INFO] Intentando instalar WinOTP via winget..." -ForegroundColor Yellow

    try {
        winget install --id JamfSoftware.WinOTP --silent --accept-package-agreements --accept-source-agreements
        Write-Host "[OK] Instalacion completada via winget." -ForegroundColor Green
    } catch {
        Write-Host "[WARN] winget no disponible. Intentando descarga directa..." -ForegroundColor Yellow

        $url  = "https://github.com/nicowillis/WinOTP/releases/latest/download/WinOTP-Setup.exe"
        $dest = "$env:TEMP\WinOTP-Setup.exe"

        try {
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
            Write-Host "[OK] Descarga completa. Instalando silenciosamente..." -ForegroundColor Green
            Start-Process -FilePath $dest -ArgumentList "/S" -Wait
            Write-Host "[OK] Instalacion completa." -ForegroundColor Green
        } catch {
            Write-Host "[ERROR] No se pudo descargar automaticamente." -ForegroundColor Red
            Write-Host ""
            Write-Host "Descarga manual requerida:" -ForegroundColor Cyan
            Write-Host "  https://github.com/nicowillis/WinOTP/releases" -ForegroundColor White
            Write-Host ""
            Write-Host "Alternativa RADIUS (sin internet):" -ForegroundColor Cyan
            Write-Host "  Instala PrivacyIDEA o FreeRADIUS en la misma red." -ForegroundColor White
        }
    }
}

Write-Host ""
Write-Host "IMPORTANTE: Reinicia el servidor despues de instalar." -ForegroundColor Magenta
Write-Host "Comando: Restart-Computer -Force" -ForegroundColor Gray

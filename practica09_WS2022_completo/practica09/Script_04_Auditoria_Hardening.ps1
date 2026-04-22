# Script_04_Auditoria_Hardening.ps1
# Usa GUIDs de subcategoria — funciona en cualquier idioma/encoding

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  HARDENING DE AUDITORIA (auditpol por GUID)" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

if (-not (Test-Path "C:\Reportes")) {
    New-Item -ItemType Directory -Path "C:\Reportes" | Out-Null
    Write-Host "  [OK] Carpeta C:\Reportes creada." -ForegroundColor Green
}

# GUIDs fijos — no dependen del idioma del sistema
$subcategorias = @{
    "Inicio de sesion"               = "{0CCE9215-69AE-11D9-BED3-505054503030}"
    "Cierre de sesion"               = "{0CCE9216-69AE-11D9-BED3-505054503030}"
    "Bloqueo de cuenta"              = "{0CCE9217-69AE-11D9-BED3-505054503030}"
    "Acceso a objetos"               = "{0CCE921F-69AE-11D9-BED3-505054503030}"
    "Sistema de archivos"            = "{0CCE921D-69AE-11D9-BED3-505054503030}"
    "Adm. cuentas de usuario"        = "{0CCE9224-69AE-11D9-BED3-505054503030}"
    "Adm. grupos de seguridad"       = "{0CCE9225-69AE-11D9-BED3-505054503030}"
    "Adm. cuentas de equipo"         = "{0CCE9223-69AE-11D9-BED3-505054503030}"
    "Cambio directiva de auditoria"  = "{0CCE922F-69AE-11D9-BED3-505054503030}"
    "Uso de privilegios sensibles"   = "{0CCE9228-69AE-11D9-BED3-505054503030}"
    "Creacion de procesos"           = "{0CCE922B-69AE-11D9-BED3-505054503030}"
}

foreach ($nombre in $subcategorias.Keys) {
    $guid = $subcategorias[$nombre]
    $resultado = auditpol /set /subcategory:"$guid" /success:enable /failure:enable 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] $nombre" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] $nombre -> $resultado" -ForegroundColor Yellow
    }
}

Write-Host "`n--- Estado actual de auditoria ---" -ForegroundColor Cyan
auditpol /get /category:*

Write-Host "`n[OK] Hardening de auditoria completado." -ForegroundColor Green
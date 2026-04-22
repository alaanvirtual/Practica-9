# ============================================================
#  MENU_Practica09_AD_Hardening.ps1
#  Menu principal - Practica 09: Hardening AD, Auditoria y MFA
#  Dominio: practica.local
#  Ejecutar como: Domain Admin en Windows Server 2022
# ============================================================

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Show-Menu {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "   PRACTICA 09 - AD Hardening, Auditoria y MFA" -ForegroundColor Cyan
    Write-Host "   Servidor : $($env:COMPUTERNAME)   Dominio: practica.local" -ForegroundColor Cyan
    Write-Host "   Usuario  : $($env:USERNAME)" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  --- CONFIGURACION DEL DOMINIO ---" -ForegroundColor DarkCyan
    Write-Host "  [1]  Crear admins, usuarios de prueba y OUs" -ForegroundColor White
    Write-Host "  [2]  Aplicar delegacion RBAC con ACLs (dsacls)" -ForegroundColor White
    Write-Host "  [3]  Crear politicas FGPP (12 chars admins / 8 chars users)" -ForegroundColor White
    Write-Host "  [4]  Hardening de Auditoria (auditpol por GUID)" -ForegroundColor White
    Write-Host ""
    Write-Host "  --- MFA Y SEGURIDAD ---" -ForegroundColor DarkCyan
    Write-Host "  [5]  Generar secretos TOTP + instalar Credential Provider" -ForegroundColor White
    Write-Host "  [6]  Configurar lockout (3 intentos admins / 5 usuarios)" -ForegroundColor White
    Write-Host "  [9]  Configurar MFA para Windows 10 y Linux Mint" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  --- REPORTES Y TESTS ---" -ForegroundColor DarkCyan
    Write-Host "  [7]  Generar Reporte de Accesos Denegados (ID 4625)" -ForegroundColor White
    Write-Host "  [8]  Ejecutar protocolo de Tests de verificacion" -ForegroundColor White
    Write-Host ""
    Write-Host "  [A]  Ejecutar TODOS en orden (1 al 9)" -ForegroundColor Green
    Write-Host "  [V]  Ver estado actual del dominio" -ForegroundColor Yellow
    Write-Host "  [U]  Desbloquear cuenta de usuario" -ForegroundColor Yellow
    Write-Host "  [S]  Salir" -ForegroundColor Red
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Run-Script {
    param([string]$NombreArchivo, [string]$Descripcion)
    $ruta = Join-Path $scriptDir $NombreArchivo
    if (Test-Path $ruta) {
        Write-Host "`n[EJECUTANDO] $Descripcion..." -ForegroundColor Yellow
        Write-Host "  Archivo: $ruta" -ForegroundColor DarkGray
        Write-Host ("-" * 60) -ForegroundColor DarkGray
        try {
            & $ruta
            Write-Host ("-" * 60) -ForegroundColor DarkGray
            Write-Host "[COMPLETADO] $Descripcion" -ForegroundColor Green
        } catch {
            Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "[ERROR] No se encontro: $ruta" -ForegroundColor Red
        Write-Host "        Asegurate de que todos los scripts esten en la misma carpeta." -ForegroundColor Yellow
    }
    Write-Host ""
    Read-Host "Presiona ENTER para continuar"
}

function Unlock-UserMenu {
    Import-Module ActiveDirectory -ErrorAction SilentlyContinue
    Write-Host "`n--- DESBLOQUEAR CUENTA ---" -ForegroundColor Yellow
    $sam = Read-Host "  SamAccountName del usuario a desbloquear"
    try {
        $u = Get-ADUser -Identity $sam -Properties LockedOut -ErrorAction Stop
        if ($u.LockedOut) {
            Unlock-ADAccount -Identity $sam
            Write-Host "[OK] Cuenta '$sam' desbloqueada." -ForegroundColor Green
        } else {
            Write-Host "[INFO] '$sam' no esta bloqueada." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[ERROR] Usuario '$sam' no encontrado: $($_.Exception.Message)" -ForegroundColor Red
    }
    Read-Host "Presiona ENTER para continuar"
}

function Show-DomainStatus {
    Clear-Host
    Import-Module ActiveDirectory -ErrorAction SilentlyContinue
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "   ESTADO ACTUAL DEL DOMINIO - practica.local" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    Write-Host "`n[ADMINS DELEGADOS]" -ForegroundColor Yellow
    foreach ($u in @("admin_identidad","admin_storage","admin_politicas","admin_auditoria")) {
        try {
            $user  = Get-ADUser -Identity $u -Properties Enabled,LockedOut,BadLogonCount,info,extensionAttribute1 -ErrorAction Stop
            $lock  = if ($user.LockedOut) { "BLOQUEADO" } else { "OK" }
            $totp  = if ($user.info -match "^TOTP:" -or $user.extensionAttribute1) { "TOTP:OK" } else { "TOTP:--" }
            Write-Host ("  {0,-20} Enabled:{1} | {2} | Fallos:{3} | {4}" -f
                $user.SamAccountName, $user.Enabled, $lock, $user.BadLogonCount, $totp)
        } catch {
            Write-Host "  $($u.PadRight(20)) [NO EXISTE]" -ForegroundColor Red
        }
    }

    Write-Host "`n[USUARIOS DE PRUEBA]" -ForegroundColor Yellow
    foreach ($u in @("usr_prueba1","usr_prueba2","usr_prueba3","usr_nocuate1","usr_nocuate2")) {
        try {
            $user  = Get-ADUser -Identity $u -Properties Enabled,LockedOut,BadLogonCount,info,extensionAttribute1 -ErrorAction Stop
            $lock  = if ($user.LockedOut) { "BLOQUEADO" } else { "OK" }
            $totp  = if ($user.info -match "^TOTP:" -or $user.extensionAttribute1) { "TOTP:OK" } else { "TOTP:--" }
            Write-Host ("  {0,-20} Enabled:{1} | {2} | Fallos:{3} | {4}" -f
                $user.SamAccountName, $user.Enabled, $lock, $user.BadLogonCount, $totp)
        } catch {
            Write-Host "  $($u.PadRight(20)) [NO EXISTE]" -ForegroundColor Red
        }
    }

    Write-Host "`n[FGPP APLICADAS]" -ForegroundColor Yellow
    try {
        $fgpp = Get-ADFineGrainedPasswordPolicy -Filter * -ErrorAction Stop
        if ($fgpp) {
            $fgpp | Select-Object Name,MinPasswordLength,LockoutThreshold,Precedence | Format-Table -AutoSize
        } else {
            Write-Host "  [NINGUNA] Ejecuta el Script 3." -ForegroundColor Red
        }
    } catch { Write-Host "  No se pudo leer FGPP." -ForegroundColor Red }

    Write-Host "[AUDITORIA]" -ForegroundColor Yellow
    auditpol /get /category:* 2>$null | Select-String "Success|Failure" | Select-Object -First 6 |
        ForEach-Object { Write-Host "  $_" }

    Write-Host "`n[CREDENTIAL PROVIDER MFA]" -ForegroundColor Yellow
    $cpKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers"
    $mfaCP = Get-ChildItem $cpKey -ErrorAction SilentlyContinue | ForEach-Object {
        (Get-ItemProperty $_.PSPath -Name "(Default)" -ErrorAction SilentlyContinue)."(Default)"
    } | Where-Object { $_ -match "SecureMFA|WinOTP|TOTP|MFA" }
    if ($mfaCP) {
        Write-Host "  [OK] $mfaCP" -ForegroundColor Green
    } else {
        Write-Host "  [--] SecureMFA no detectado. Ejecuta Script [5] y [9]." -ForegroundColor Yellow
    }

    Write-Host "`n[REPORTES GENERADOS]" -ForegroundColor Yellow
    $reportDir = "C:\Reportes"
    if (Test-Path $reportDir) {
        $archivos = Get-ChildItem $reportDir -Recurse -File |
            Select-Object Name, LastWriteTime, @{N="KB";E={"$([math]::Round($_.Length/1KB,1))"}}
        if ($archivos) { $archivos | Format-Table -AutoSize }
        else { Write-Host "  Carpeta vacia." }
    } else {
        Write-Host "  C:\Reportes no existe. Ejecuta Script 4." -ForegroundColor Yellow
    }

    Write-Host "============================================================" -ForegroundColor Cyan
    Read-Host "`nPresiona ENTER para volver al menu"
}

# ── BUCLE PRINCIPAL ──────────────────────────────────────────
do {
    Show-Menu
    $opcion = Read-Host "  Selecciona una opcion"
    switch ($opcion.ToUpper()) {
        "1" { Run-Script "Script_01_Crear_Usuarios_RBAC.ps1"        "Crear admins y usuarios de prueba" }
        "2" { Run-Script "Script_02_Delegacion_RBAC.ps1"            "Delegacion RBAC con ACLs" }
        "3" { Run-Script "Script_03_FGPP.ps1"                       "Politicas FGPP de contrasena" }
        "4" { Run-Script "Script_04_Auditoria_Hardening.ps1"        "Hardening de auditoria" }
        "5" { Run-Script "Script_06_Instalar_MFA_SecureMFA.ps1"     "Generar TOTP e instalar Credential Provider" }
        "6" { Run-Script "Script_07_Lockout_MFA.ps1"                "Configurar lockout por MFA" }
        "7" { Run-Script "Script_05_Reporte_Auditoria.ps1"          "Reporte de accesos denegados" }
        "8" { Run-Script "Script_08_Tests_Verificacion.ps1"         "Protocolo de tests" }
        "9" { Run-Script "Script_09_Configurar_MFA_Clientes.ps1"    "Configurar MFA en Win10 y Linux Mint" }
        "A" {
            Clear-Host
            Write-Host "  Ejecutando TODOS los scripts en orden..." -ForegroundColor Green
            $todos = @(
                @("Script_01_Crear_Usuarios_RBAC.ps1",       "1. Crear usuarios y OUs"),
                @("Script_02_Delegacion_RBAC.ps1",           "2. Delegacion RBAC"),
                @("Script_03_FGPP.ps1",                      "3. Politicas FGPP"),
                @("Script_04_Auditoria_Hardening.ps1",       "4. Hardening auditoria"),
                @("Script_06_Instalar_MFA_SecureMFA.ps1",    "5. MFA TOTP"),
                @("Script_07_Lockout_MFA.ps1",               "6. Lockout MFA"),
                @("Script_05_Reporte_Auditoria.ps1",         "7. Reporte eventos"),
                @("Script_08_Tests_Verificacion.ps1",        "8. Tests verificacion"),
                @("Script_09_Configurar_MFA_Clientes.ps1",   "9. Config clientes Win10/Linux")
            )
            foreach ($s in $todos) {
                $rutaS = Join-Path $scriptDir $s[0]
                if (Test-Path $rutaS) {
                    Write-Host "`n  > $($s[1])" -ForegroundColor Yellow
                    try { & $rutaS } catch { Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red }
                } else {
                    Write-Host "  [OMITIDO] $($s[0]) no encontrado." -ForegroundColor DarkYellow
                }
            }
            Write-Host "`n[COMPLETADO] Todos los scripts ejecutados." -ForegroundColor Green
            Read-Host "Presiona ENTER para continuar"
        }
        "V" { Show-DomainStatus }
        "U" { Unlock-UserMenu }
        "S" { Write-Host "`n  Saliendo. Hasta luego!" -ForegroundColor Cyan; break }
        default { Write-Host "  [WARN] Opcion no valida." -ForegroundColor Yellow; Start-Sleep 1 }
    }
} while ($opcion.ToUpper() -ne "S")

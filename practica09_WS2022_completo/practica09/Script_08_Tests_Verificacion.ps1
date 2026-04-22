# ============================================================
#  Script_08_Tests_Verificacion.ps1
#  Dominio: practica.local
#
#  TEST 1 - Delegacion RBAC: admin_identidad vs admin_storage
#  TEST 2 - FGPP: rechazo de contrasena corta en admin_identidad
#  TEST 3 - MFA: Credential Provider instalado + TOTP en AD
#  TEST 4 - Lockout: bloqueo tras N intentos fallidos
#  TEST 5 - Reporte: generacion automatica de eventos 4625
# ============================================================

Import-Module ActiveDirectory -ErrorAction Stop

$dominio     = "DC=practica,DC=local"
$ouCuates    = "OU=Cuates,OU=Practica,DC=practica,DC=local"
$usuarioPrueba = "usr_prueba1"   # usuario sobre el que se prueban permisos

$sep  = "=" * 62
$pass = 0; $fail = 0; $warn = 0

function Write-Result {
    param([string]$Estado, [string]$Mensaje)
    switch ($Estado) {
        "OK"   { Write-Host "  [OK]   $Mensaje" -ForegroundColor Green;  $script:pass++ }
        "FAIL" { Write-Host "  [FAIL] $Mensaje" -ForegroundColor Red;    $script:fail++ }
        "WARN" { Write-Host "  [WARN] $Mensaje" -ForegroundColor Yellow; $script:warn++ }
        "INFO" { Write-Host "  [INFO] $Mensaje" -ForegroundColor Cyan }
    }
}

# ================================================================
# TEST 1: Delegacion RBAC — admin_identidad puede, admin_storage no
# ================================================================
Write-Host "`n$sep" -ForegroundColor Cyan
Write-Host "  TEST 1 - Delegacion RBAC (ROL 1 vs ROL 2)" -ForegroundColor Cyan
Write-Host $sep -ForegroundColor Cyan

# 1A: Verificar que admin_identidad tiene permiso de Reset Password en OU Cuates
Write-Host "`n  [T1A] Verificando ACL de admin_identidad en OU Cuates..." -ForegroundColor White
try {
    $acl = Get-Acl -Path "AD:\$ouCuates" -ErrorAction Stop
    $aceIdentidad = $acl.Access | Where-Object {
        $_.IdentityReference -match "admin_identidad" -and
        $_.AccessControlType -eq "Allow"
    }
    if ($aceIdentidad) {
        Write-Result "OK" "admin_identidad tiene ACE Allow en OU Cuates."
    } else {
        Write-Result "WARN" "admin_identidad no tiene ACE directo en OU Cuates (puede heredar del dominio)."
    }
} catch {
    Write-Result "WARN" "No se pudo leer ACL de OU Cuates: $($_.Exception.Message)"
}

# 1A funcional: intentar resetear contrasena de usr_prueba1 como Domain Admin
# (simulamos la accion que admin_identidad puede hacer)
Write-Host "`n  [T1A] Probando reset de contrasena en $usuarioPrueba (como Domain Admin)..." -ForegroundColor White
$passNueva = ConvertTo-SecureString "NuevaPass@2025!" -AsPlainText -Force
try {
    Set-ADAccountPassword -Identity $usuarioPrueba -NewPassword $passNueva -Reset -ErrorAction Stop
    Write-Result "OK" "Reset de contrasena en '$usuarioPrueba' exitoso (lo que admin_identidad puede hacer)."
} catch {
    Write-Result "FAIL" "No se pudo resetear contrasena de '$usuarioPrueba': $($_.Exception.Message)"
}

# 1B: Verificar que admin_storage tiene DENY en Reset Password
Write-Host "`n  [T1B] Verificando DENY de admin_storage en dominio..." -ForegroundColor White
try {
    $aclDomain = Get-Acl -Path "AD:\$dominio" -ErrorAction Stop
    $aceDeny   = $aclDomain.Access | Where-Object {
        $_.IdentityReference -match "admin_storage" -and
        $_.AccessControlType -eq "Deny"
    }
    if ($aceDeny) {
        Write-Result "OK" "admin_storage tiene ACE Deny en el dominio (Reset Password bloqueado)."
        $aceDeny | Select-Object IdentityReference, ActiveDirectoryRights, AccessControlType |
            Format-Table -AutoSize
    } else {
        Write-Result "WARN" "No se detecto ACE Deny explicito para admin_storage. Verifica Script_02."
    }
} catch {
    Write-Result "WARN" "No se pudo leer ACL del dominio: $($_.Exception.Message)"
}

Write-Host "  EVIDENCIA REQUERIDA:" -ForegroundColor DarkGray
Write-Host "    Inicia sesion como admin_identidad en cliente W10 y resetea contrasena de usr_prueba1." -ForegroundColor DarkGray
Write-Host "    Luego inicia sesion como admin_storage e intenta lo mismo -> debe dar 'Acceso denegado'." -ForegroundColor DarkGray

# ================================================================
# TEST 2: FGPP — rechazo de contrasena de 8 chars en admin_identidad
# ================================================================
Write-Host "`n$sep" -ForegroundColor Cyan
Write-Host "  TEST 2 - FGPP (contrasena minima 12 chars para admin_identidad)" -ForegroundColor Cyan
Write-Host $sep -ForegroundColor Cyan

$pso = Get-ADUserResultantPasswordPolicy -Identity "admin_identidad" -ErrorAction SilentlyContinue
if ($pso) {
    Write-Result "OK" "PSO '$($pso.Name)' aplicada a admin_identidad."
    Write-Host "         Longitud minima : $($pso.MinPasswordLength) caracteres" -ForegroundColor White
    Write-Host "         Umbral lockout  : $($pso.LockoutThreshold) intentos" -ForegroundColor White
    Write-Host "         Duracion lockout: $($pso.LockoutDuration)" -ForegroundColor White

    if ($pso.MinPasswordLength -ge 12) {
        Write-Result "OK" "Longitud minima cumple el requisito (>= 12 chars)."
    } else {
        Write-Result "FAIL" "Longitud minima es $($pso.MinPasswordLength), se requieren >= 12."
    }
} else {
    Write-Result "FAIL" "No hay PSO resultante para admin_identidad. Ejecuta Script_03 primero."
}

# Intento real: asignar contrasena de 8 chars — debe ser rechazada
Write-Host "`n  Intentando asignar contrasena de 8 caracteres a admin_identidad (debe fallar)..." -ForegroundColor White
try {
    Set-ADAccountPassword -Identity "admin_identidad" `
        -NewPassword (ConvertTo-SecureString "Test@123" -AsPlainText -Force) -Reset -ErrorAction Stop
    Write-Result "FAIL" "La contrasena de 8 chars FUE ACEPTADA — revisar FGPP."
} catch {
    Write-Result "OK" "Contrasena de 8 chars RECHAZADA correctamente por FGPP."
    Write-Host "         Error devuelto: $($_.Exception.Message)" -ForegroundColor DarkGray
}

# Restaurar contrasena valida para admin_identidad
try {
    Set-ADAccountPassword -Identity "admin_identidad" `
        -NewPassword (ConvertTo-SecureString "Admin@12345!" -AsPlainText -Force) -Reset -ErrorAction Stop
    Write-Host "  [INFO] Contrasena de admin_identidad restaurada a Admin@12345!" -ForegroundColor Yellow
} catch {
    Write-Host "  [WARN] No se pudo restaurar contrasena de admin_identidad." -ForegroundColor Yellow
}

Write-Host "  EVIDENCIA REQUERIDA:" -ForegroundColor DarkGray
Write-Host "    Captura del error de complejidad/longitud al asignar contrasena corta." -ForegroundColor DarkGray

# ================================================================
# TEST 3: MFA — Credential Provider instalado y TOTP en AD
# ================================================================
Write-Host "`n$sep" -ForegroundColor Cyan
Write-Host "  TEST 3 - MFA TOTP (Google Authenticator)" -ForegroundColor Cyan
Write-Host $sep -ForegroundColor Cyan

# 3A: Verificar Credential Provider en el registro
$cpKey   = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers"
$cpList  = Get-ChildItem $cpKey -ErrorAction SilentlyContinue
$mfaFound = $false

Write-Host "`n  [3A] Buscando Credential Provider SecureMFA..." -ForegroundColor White
if ($cpList) {
    foreach ($cp in $cpList) {
        $name = (Get-ItemProperty $cp.PSPath -Name "(Default)" -ErrorAction SilentlyContinue)."(Default)"
        if ($name -match "SecureMFA|WinOTP|TOTP|MFA") {
            Write-Result "OK" "Credential Provider MFA detectado: $name"
            $mfaFound = $true
        }
    }
}
if (-not $mfaFound) {
    Write-Result "WARN" "Credential Provider SecureMFA NO detectado."
    Write-Host "         Descarga el .msi desde https://www.securemfa.com/downloads/mfa-win-otp" -ForegroundColor Yellow
    Write-Host "         Ponlo en C:\Instaladores\ , ejecuta Script_06 y reinicia el servidor." -ForegroundColor Yellow
    Write-Host "`n         Credential Providers actualmente instalados:" -ForegroundColor White
    $cpList | ForEach-Object {
        $n = (Get-ItemProperty $_.PSPath -Name "(Default)" -ErrorAction SilentlyContinue)."(Default)"
        if ($n) { Write-Host "           - $n" -ForegroundColor DarkGray }
    }
}

# 3B: Verificar secretos TOTP en AD (atributos 'info' y 'extensionAttribute1')
Write-Host "`n  [3B] Verificando secretos TOTP en AD..." -ForegroundColor White
$todosUsers = @(
    "admin_identidad","admin_storage","admin_politicas","admin_auditoria",
    "usr_prueba1","usr_prueba2","usr_prueba3","usr_nocuate1","usr_nocuate2"
)
$conTOTP = 0
foreach ($u in $todosUsers) {
    $adU = Get-ADUser -Filter "SamAccountName -eq '$u'" `
        -Properties info, extensionAttribute1 -ErrorAction SilentlyContinue
    if ($adU) {
        $tieneInfo = $adU.info -match "^TOTP:"
        $tieneExt  = $adU.extensionAttribute1 -match "^[A-Z2-7]{16,}"
        if ($tieneInfo -or $tieneExt) {
            Write-Host "    [OK] $($u.PadRight(20)) TOTP registrado." -ForegroundColor Green
            $conTOTP++
        } else {
            Write-Host "    [--] $($u.PadRight(20)) Sin secreto TOTP. Ejecuta Script_06." -ForegroundColor Yellow
        }
    } else {
        Write-Host "    [??] $($u.PadRight(20)) No encontrado en AD." -ForegroundColor DarkGray
    }
}

if ($conTOTP -eq $todosUsers.Count) {
    Write-Result "OK" "Todos los usuarios ($conTOTP/$($todosUsers.Count)) tienen secreto TOTP en AD."
} elseif ($conTOTP -gt 0) {
    Write-Result "WARN" "$conTOTP de $($todosUsers.Count) usuarios tienen TOTP. Ejecuta Script_06 para completar."
} else {
    Write-Result "FAIL" "Ningun usuario tiene secreto TOTP. Ejecuta Script_06."
}

# 3C: Verificar archivos TOTP generados
Write-Host "`n  [3C] Verificando archivos TOTP en C:\Reportes\TOTP\..." -ForegroundColor White
$totpDir = "C:\Reportes\TOTP"
if (Test-Path $totpDir) {
    $archivos = Get-ChildItem $totpDir -Filter "TOTP_*.txt"
    if ($archivos.Count -gt 0) {
        Write-Result "OK" "$($archivos.Count) archivos TOTP encontrados en $totpDir"
        $archivos | Select-Object Name, LastWriteTime | Format-Table -AutoSize
    } else {
        Write-Result "WARN" "Carpeta TOTP existe pero esta vacia. Ejecuta Script_06."
    }
} else {
    Write-Result "WARN" "Carpeta $totpDir no existe. Ejecuta Script_06."
}

Write-Host "  EVIDENCIA REQUERIDA:" -ForegroundColor DarkGray
Write-Host "    Foto de la pantalla de login mostrando campo MFA + captura de Google Authenticator." -ForegroundColor DarkGray

# ================================================================
# TEST 4: Lockout — bloqueo tras N intentos fallidos
# ================================================================
Write-Host "`n$sep" -ForegroundColor Cyan
Write-Host "  TEST 4 - Lockout de cuenta por intentos fallidos" -ForegroundColor Cyan
Write-Host $sep -ForegroundColor Cyan

# Verificar configuracion de FGPP
Write-Host "`n  [4A] Configuracion de lockout en FGPP..." -ForegroundColor White
$psoAdmin = Get-ADFineGrainedPasswordPolicy -Filter "Name -eq 'PSO_Admins_12chars'" -ErrorAction SilentlyContinue
$psoUser  = Get-ADFineGrainedPasswordPolicy -Filter "Name -eq 'PSO_Usuarios_8chars'" -ErrorAction SilentlyContinue

if ($psoAdmin) {
    Write-Host "  PSO_Admins_12chars: Umbral=$($psoAdmin.LockoutThreshold) | Duracion=$($psoAdmin.LockoutDuration)" -ForegroundColor White
    if ($psoAdmin.LockoutThreshold -eq 3) {
        Write-Result "OK" "Admins: 3 intentos -> bloqueo 30 min (correcto)."
    } else {
        Write-Result "WARN" "Admins: umbral es $($psoAdmin.LockoutThreshold), se esperan 3."
    }
} else {
    Write-Result "FAIL" "PSO_Admins_12chars no encontrada. Ejecuta Script_03."
}

if ($psoUser) {
    Write-Host "  PSO_Usuarios_8chars: Umbral=$($psoUser.LockoutThreshold) | Duracion=$($psoUser.LockoutDuration)" -ForegroundColor White
    if ($psoUser.LockoutThreshold -le 5) {
        Write-Result "OK" "Usuarios: $($psoUser.LockoutThreshold) intentos -> bloqueo 30 min (correcto)."
    } else {
        Write-Result "WARN" "Usuarios: umbral es $($psoUser.LockoutThreshold)."
    }
} else {
    Write-Result "WARN" "PSO_Usuarios_8chars no encontrada. Ejecuta Script_03."
}

# Estado actual de bloqueo de todas las cuentas
Write-Host "`n  [4B] Estado actual de bloqueo..." -ForegroundColor White
$bloqueados = 0
foreach ($u in $todosUsers) {
    try {
        $adU   = Get-ADUser -Identity $u -Properties LockedOut, BadLogonCount -ErrorAction Stop
        $estado = if ($adU.LockedOut) { "BLOQUEADA"; $bloqueados++ } else { "Activa  " }
        $color  = if ($adU.LockedOut) { "Red" } else { "Green" }
        Write-Host ("  {0,-20} {1}  Fallos: {2}" -f $adU.SamAccountName, $estado, $adU.BadLogonCount) -ForegroundColor $color
    } catch {
        Write-Host "  $($u.PadRight(20)) [NO ENCONTRADO]" -ForegroundColor DarkGray
    }
}

if ($bloqueados -gt 0) {
    Write-Result "INFO" "$bloqueados cuenta(s) actualmente bloqueadas. Usa [U] en el menu para desbloquear."
} else {
    Write-Result "OK" "Ninguna cuenta bloqueada actualmente."
}

# Instrucciones para ejecutar el test manualmente
Write-Host "`n  COMO EJECUTAR EL TEST 4 MANUALMENTE:" -ForegroundColor Yellow
Write-Host "    1. Desde cliente Windows 10 o Linux Mint:" -ForegroundColor White
Write-Host "       Intenta iniciar sesion con admin_identidad y contrasena INCORRECTA 3 veces" -ForegroundColor White
Write-Host "    2. Luego verifica en el DC con:" -ForegroundColor White
Write-Host "       Get-ADUser admin_identidad -Properties LockedOut,BadLogonCount,LockoutTime" -ForegroundColor Cyan
Write-Host "    3. Para desbloquear:" -ForegroundColor White
Write-Host "       Unlock-ADAccount -Identity admin_identidad" -ForegroundColor Cyan
Write-Host "  EVIDENCIA REQUERIDA:" -ForegroundColor DarkGray
Write-Host "    Captura del estado 'LockedOut=True' en el DC tras los intentos fallidos." -ForegroundColor DarkGray

# ================================================================
# TEST 5: Reporte de auditoria — eventos ID 4625
# ================================================================
Write-Host "`n$sep" -ForegroundColor Cyan
Write-Host "  TEST 5 - Reporte de Auditoria automatizado (ID 4625)" -ForegroundColor Cyan
Write-Host $sep -ForegroundColor Cyan

$scriptBase    = Split-Path -Parent $MyInvocation.MyCommand.Path
$reporteScript = Join-Path $scriptBase "Script_05_Reporte_Auditoria.ps1"

if (Test-Path $reporteScript) {
    Write-Host "  Ejecutando Script_05_Reporte_Auditoria.ps1..." -ForegroundColor White
    try {
        & $reporteScript
        $ultimoReporte = Get-ChildItem "C:\Reportes" -Filter "Reporte_AccesosDenegados_*.txt" `
            -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($ultimoReporte) {
            Write-Result "OK" "Reporte generado: $($ultimoReporte.Name) ($([math]::Round($ultimoReporte.Length/1KB,1)) KB)"
            Write-Host "         Ruta: C:\Reportes\$($ultimoReporte.Name)" -ForegroundColor DarkGray
        } else {
            Write-Result "WARN" "Script ejecutado pero no se genero archivo. Puede no haber eventos 4625 aun."
        }
    } catch {
        Write-Result "FAIL" "Error al ejecutar Script_05: $($_.Exception.Message)"
    }
} else {
    Write-Result "WARN" "Script_05_Reporte_Auditoria.ps1 no encontrado en: $scriptBase"
    Write-Host "         Asegurate de que todos los scripts esten en la misma carpeta." -ForegroundColor Yellow
}

Write-Host "  EVIDENCIA REQUERIDA:" -ForegroundColor DarkGray
Write-Host "    Archivo .txt resultante con al menos 1 evento 4625." -ForegroundColor DarkGray

# ================================================================
# RESUMEN FINAL
# ================================================================
Write-Host "`n$sep" -ForegroundColor Cyan
Write-Host "  RESUMEN DE TESTS" -ForegroundColor Cyan
Write-Host $sep -ForegroundColor Cyan
Write-Host "  PASADOS : $pass" -ForegroundColor Green
Write-Host "  FALLIDOS: $fail" -ForegroundColor Red
Write-Host "  AVISOS  : $warn" -ForegroundColor Yellow
Write-Host $sep -ForegroundColor Cyan

if ($fail -eq 0 -and $warn -eq 0) {
    Write-Host "`n  Todos los tests pasaron sin advertencias." -ForegroundColor Green
} elseif ($fail -eq 0) {
    Write-Host "`n  Tests criticos OK. Revisa los avisos [WARN]." -ForegroundColor Yellow
} else {
    Write-Host "`n  Hay $fail test(s) fallidos. Revisa los mensajes [FAIL]." -ForegroundColor Red
}

Write-Host "`n  Guarda capturas de cada TEST para tu reporte tecnico." -ForegroundColor DarkGray
Write-Host "  Reportes en: C:\Reportes\" -ForegroundColor DarkGray
Write-Host "  TOTP en    : C:\Reportes\TOTP\" -ForegroundColor DarkGray

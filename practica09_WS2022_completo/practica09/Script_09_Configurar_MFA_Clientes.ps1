# ============================================================
#  Script_09_Configurar_MFA_Clientes.ps1
#  Ejecutar en el DC como Domain Admin
#  
#  Genera todo lo necesario para que Windows 10 y Linux Mint
#  pidan el codigo de Google Authenticator al iniciar sesion:
#
#  WINDOWS 10:
#    - El Credential Provider de SecureMFA intercepta el login
#    - Pide usuario + contrasena + codigo TOTP de 6 digitos
#    - Requiere instalar SecureMFA_WinOTP.msi en el cliente W10
#
#  LINUX MINT:
#    - Usa PAM + oathtool para verificar el codigo TOTP
#    - El script genera el archivo de configuracion PAM
#    - Requiere ejecutar los comandos de instalacion en el cliente
#
#  Dominio: practica.local
# ============================================================

Import-Module ActiveDirectory -ErrorAction Stop

$dominioFQDN = "practica.local"
$reportDir   = "C:\Reportes\TOTP"
$configDir   = "C:\Reportes\ClienteConfig"

if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  CONFIGURACION MFA PARA CLIENTES" -ForegroundColor Cyan
Write-Host "  Windows 10 + Linux Mint" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ── PARTE 1: WINDOWS 10 ─────────────────────────────────────
Write-Host "`n============================================================" -ForegroundColor Yellow
Write-Host "  PARTE 1 - WINDOWS 10 (Credential Provider SecureMFA)" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Write-Host @"

  COMO FUNCIONA EN WINDOWS 10:
  El Credential Provider de SecureMFA se instala en el cliente Windows 10.
  Cuando el usuario intenta iniciar sesion en el dominio, aparece un campo
  adicional despues de la contrasena donde debe ingresar el codigo TOTP
  de 6 digitos de Google Authenticator.

  PASOS A EJECUTAR EN CADA CLIENTE WINDOWS 10:
  -----------------------------------------------
  1. Descarga SecureMFA_WinOTP.msi desde el servidor o desde:
     https://www.securemfa.com/downloads/mfa-win-otp

  2. Ejecuta el instalador como Administrador:
     msiexec /i SecureMFA_WinOTP.msi /quiet /norestart

  3. Reinicia el cliente Windows 10.

  4. En la pantalla de login veras el campo adicional de MFA.

  5. El usuario ingresa: usuario + contrasena + codigo Google Authenticator.

  PARA DISTRIBUIR EL .MSI DESDE EL DC VIA GPO:
  -----------------------------------------------
  Computer Configuration > Policies > Software Settings > Software Installation
  Agrega el .msi desde un share de red y asigna a los equipos del dominio.

"@ -ForegroundColor White

# Generar script de instalacion para Windows 10
$scriptW10 = @"
# Instalar_MFA_Windows10.bat
# Ejecutar como Administrador en cada cliente Windows 10
# Coloca SecureMFA_WinOTP.msi en la misma carpeta que este script

@echo off
echo Instalando SecureMFA WIN OTP Credential Provider...
msiexec /i "%~dp0SecureMFA_WinOTP.msi" /quiet /norestart
if %ERRORLEVEL%==0 (
    echo [OK] Instalacion completada. Reinicia el equipo.
) else (
    echo [ERROR] La instalacion fallo con codigo %ERRORLEVEL%
)
pause
"@

$scriptW10Path = "$configDir\Instalar_MFA_Windows10.bat"
$scriptW10 | Out-File $scriptW10Path -Encoding ASCII
Write-Host "  [OK] Script de instalacion para Windows 10 generado:" -ForegroundColor Green
Write-Host "       $scriptW10Path" -ForegroundColor DarkGray

# ── PARTE 2: LINUX MINT ─────────────────────────────────────
Write-Host "`n============================================================" -ForegroundColor Yellow
Write-Host "  PARTE 2 - LINUX MINT (PAM + SSSD + oathtool)" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Write-Host @"

  COMO FUNCIONA EN LINUX MINT:
  Linux Mint se une al dominio AD mediante SSSD + Realmd.
  El MFA se implementa con PAM (Pluggable Authentication Module) y
  la herramienta oathtool que verifica los codigos TOTP.
  Al iniciar sesion (GDM, terminal o SSH), el sistema pedira el
  codigo de Google Authenticator.

"@ -ForegroundColor White

# Generar script de configuracion para Linux Mint
$scriptLinux = @'
#!/bin/bash
# ============================================================
#  Configurar_MFA_LinuxMint.sh
#  Ejecutar como root en cada cliente Linux Mint
#  Dominio: practica.local
#
#  Este script:
#    1. Une Linux Mint al dominio AD (si no esta unido)
#    2. Instala oathtool para verificacion TOTP
#    3. Configura PAM para pedir codigo MFA al iniciar sesion
#    4. Crea el archivo de secretos TOTP por usuario
# ============================================================

set -e

DOMINIO="practica.local"
DC_IP=""   # <-- REEMPLAZA con la IP de tu Windows Server 2022
ADMIN_DOMINIO="Administrador"

echo ""
echo "============================================================"
echo "  PASO 1 - Instalando herramientas de union al dominio"
echo "============================================================"

apt-get update -qq
apt-get install -y \
    sssd \
    sssd-tools \
    realmd \
    adcli \
    krb5-user \
    samba-common-bin \
    packagekit \
    libnss-sss \
    libpam-sss \
    oddjob \
    oddjob-mkhomedir \
    oathtool \
    libpam-oath \
    libqrencode3 \
    qrencode

echo "[OK] Paquetes instalados."

echo ""
echo "============================================================"
echo "  PASO 2 - Union al dominio AD"
echo "============================================================"

# Verificar si ya esta unido
if realm list 2>/dev/null | grep -q "$DOMINIO"; then
    echo "[INFO] Ya unido al dominio $DOMINIO."
else
    echo "[INFO] Uniendo al dominio $DOMINIO..."
    echo "Introduce la contrasena del Administrador del dominio cuando se solicite:"
    realm join "$DOMINIO" -U "$ADMIN_DOMINIO" --install=/
    echo "[OK] Union al dominio completada."
fi

echo ""
echo "============================================================"
echo "  PASO 3 - Configurando SSSD"
echo "============================================================"

cat > /etc/sssd/sssd.conf << SSSDEOF
[sssd]
domains = $DOMINIO
config_file_version = 2
services = nss, pam, sudo

[domain/$DOMINIO]
ad_domain = $DOMINIO
krb5_realm = PRACTICA.LOCAL
realmd_tags = manages-system joined-with-adcli
cache_credentials = True
id_provider = ad
fallback_homedir = /home/%u@%d
default_shell = /bin/bash
use_fully_qualified_names = False
access_provider = ad
ldap_id_mapping = True
SSSDEOF

chmod 600 /etc/sssd/sssd.conf
systemctl restart sssd
systemctl enable sssd
echo "[OK] SSSD configurado y reiniciado."

echo ""
echo "============================================================"
echo "  PASO 4 - Habilitando creacion automatica de carpeta home"
echo "============================================================"

pam-auth-update --enable mkhomedir
echo "[OK] mkhomedir habilitado."

echo ""
echo "============================================================"
echo "  PASO 5 - Configurando MFA con PAM + oathtool (TOTP)"
echo "============================================================"

# Crear directorio para secretos TOTP
mkdir -p /etc/security/totp
chmod 700 /etc/security/totp

# Agregar usuario al grupo sudo (opcional)
# echo "%domain^admins ALL=(ALL) ALL" >> /etc/sudoers.d/domain-admins

# Configurar PAM para pedir TOTP en login interactivo
# Modificar /etc/pam.d/common-auth para agregar MFA

PAM_COMMON="/etc/pam.d/common-auth"

# Hacer backup
cp "$PAM_COMMON" "${PAM_COMMON}.bak_$(date +%Y%m%d%H%M%S)"

# Verificar si ya esta configurado
if grep -q "pam_oath" "$PAM_COMMON"; then
    echo "[INFO] PAM OATH ya esta configurado."
else
    # Agregar MFA despues de la autenticacion de contrasena
    # El 'nullok' permite acceso si el archivo de secreto no existe aun
    sed -i '/^auth.*pam_sss.so/a auth    required    pam_oath.so usersfile=/etc/security/totp/users.oath window=1 digits=6' "$PAM_COMMON"
    echo "[OK] PAM configurado para pedir codigo TOTP."
fi

echo ""
echo "============================================================"
echo "  PASO 6 - Creando archivo de secretos TOTP"
echo "============================================================"
echo ""
echo "Ahora ingresa los secretos TOTP de cada usuario."
echo "Los secretos estan en el servidor DC en C:\Reportes\TOTP\TOTP_<usuario>.txt"
echo ""

USERS_OATH="/etc/security/totp/users.oath"
> "$USERS_OATH"   # limpiar archivo

declare -A SECRETOS=(
    # Agrega aqui los secretos de tus usuarios
    # Formato: ["usuario"]="SECRETO_BASE32"
    # Los secretos estan en C:\Reportes\TOTP\ en el servidor
    ["admin_identidad"]="SECRETO_AQUI"
    ["admin_storage"]="SECRETO_AQUI"
    ["admin_politicas"]="SECRETO_AQUI"
    ["admin_auditoria"]="SECRETO_AQUI"
    ["usr_prueba1"]="SECRETO_AQUI"
    ["usr_prueba2"]="SECRETO_AQUI"
    ["usr_prueba3"]="SECRETO_AQUI"
    ["usr_nocuate1"]="SECRETO_AQUI"
    ["usr_nocuate2"]="SECRETO_AQUI"
)

for usuario in "${!SECRETOS[@]}"; do
    secreto="${SECRETOS[$usuario]}"
    if [ "$secreto" != "SECRETO_AQUI" ]; then
        echo "HOTP/T30/6 $usuario - $secreto" >> "$USERS_OATH"
        echo "  [OK] $usuario agregado."
    else
        echo "  [WARN] $usuario - secreto no configurado. Edita este script."
    fi
done

chmod 600 "$USERS_OATH"
echo "[OK] Archivo de secretos creado: $USERS_OATH"

echo ""
echo "============================================================"
echo "  COMO VERIFICAR QUE FUNCIONA"
echo "============================================================"
echo ""
echo "  1. Cierra sesion y vuelve a iniciar sesion."
echo "     El sistema pedira: usuario, contrasena y codigo MFA."
echo ""
echo "  2. Para probar el codigo TOTP manualmente:"
echo "     oathtool --totp -b SECRETO_BASE32"
echo "     (devuelve el codigo valido en este momento)"
echo ""
echo "  3. Para verificar que el usuario del dominio es reconocido:"
echo "     id admin_identidad@practica.local"
echo "     getent passwd admin_identidad"
echo ""
echo "[OK] Configuracion MFA para Linux Mint completada."
echo "     REINICIA el cliente para aplicar todos los cambios."
'@

$scriptLinuxPath = "$configDir\Configurar_MFA_LinuxMint.sh"
$scriptLinux | Out-File $scriptLinuxPath -Encoding UTF8 -NoNewline

Write-Host "  [OK] Script de configuracion para Linux Mint generado:" -ForegroundColor Green
Write-Host "       $scriptLinuxPath" -ForegroundColor DarkGray

# ── PARTE 3: Generar secretos listos para pegar en el script Linux
Write-Host "`n============================================================" -ForegroundColor Yellow
Write-Host "  PARTE 3 - Exportando secretos para pegar en Linux Mint" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

$usuarios = @(
    "admin_identidad","admin_storage","admin_politicas","admin_auditoria",
    "usr_prueba1","usr_prueba2","usr_prueba3","usr_nocuate1","usr_nocuate2"
)

$secretosLinux = "# Secretos TOTP para pegar en Configurar_MFA_LinuxMint.sh`n"
$secretosLinux += "# Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n"
$secretosLinux += "# Pega estas lineas en la seccion declare -A SECRETOS del script`n`n"

$usersOath = "# Archivo users.oath para Linux Mint`n"
$usersOath += "# Copiar a /etc/security/totp/users.oath`n"
$usersOath += "# Formato: HOTP/T30/6 usuario - SECRETO`n`n"

foreach ($sam in $usuarios) {
    $adU = Get-ADUser -Filter "SamAccountName -eq '$sam'" `
        -Properties info, extensionAttribute1 -ErrorAction SilentlyContinue

    if ($adU) {
        $secreto = $null
        if ($adU.info -match "^TOTP:([A-Z2-7]+)") {
            $secreto = $Matches[1]
        } elseif ($adU.extensionAttribute1 -match "^[A-Z2-7]{16,}") {
            $secreto = $adU.extensionAttribute1
        }

        if ($secreto) {
            $secretosLinux += "    [`"$sam`"]`=`"$secreto`"`n"
            $usersOath     += "HOTP/T30/6 $sam - $secreto`n"
            Write-Host "  [OK] $($sam.PadRight(20)) Secreto: $secreto" -ForegroundColor Green
        } else {
            $secretosLinux += "    [`"$sam`"]`=`"SIN_SECRETO_EJECUTA_SCRIPT06`"`n"
            $usersOath     += "# $sam - SIN SECRETO (ejecuta Script_06 primero)`n"
            Write-Host "  [--] $($sam.PadRight(20)) Sin secreto. Ejecuta Script_06." -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [??] $($sam.PadRight(20)) No encontrado en AD." -ForegroundColor DarkGray
    }
}

# Guardar archivos de secretos
$secretosLinux | Out-File "$configDir\Secretos_Para_Linux.txt" -Encoding UTF8
$usersOath     | Out-File "$configDir\users.oath"              -Encoding UTF8

Write-Host "`n  [OK] Archivos generados:" -ForegroundColor Green
Write-Host "       $configDir\Secretos_Para_Linux.txt  <- pegar en el script bash" -ForegroundColor DarkGray
Write-Host "       $configDir\users.oath               <- copiar a /etc/security/totp/" -ForegroundColor DarkGray

# ── RESUMEN DE PASOS ─────────────────────────────────────────
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  RESUMEN - PASOS FINALES PARA ACTIVAR MFA" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host @"

  WINDOWS 10 (en cada cliente):
  ┌─────────────────────────────────────────────────────────┐
  │ 1. Descarga SecureMFA_WinOTP.msi desde:                 │
  │    https://www.securemfa.com/downloads/mfa-win-otp      │
  │ 2. Copia el .msi al cliente Windows 10                  │
  │ 3. Ejecuta Instalar_MFA_Windows10.bat como Admin        │
  │    (esta en C:\Reportes\ClienteConfig\)                 │
  │ 4. Reinicia el cliente                                  │
  │ 5. Al iniciar sesion aparece el campo adicional MFA     │
  │ 6. El usuario abre Google Authenticator y escribe       │
  │    el codigo de 6 digitos                               │
  └─────────────────────────────────────────────────────────┘

  LINUX MINT (en cada cliente):
  ┌─────────────────────────────────────────────────────────┐
  │ 1. Copia al cliente Linux Mint:                         │
  │    - Configurar_MFA_LinuxMint.sh                        │
  │    - users.oath                                         │
  │    (estan en C:\Reportes\ClienteConfig\ del servidor)   │
  │ 2. En Linux Mint como root:                             │
  │    chmod +x Configurar_MFA_LinuxMint.sh                 │
  │    sudo ./Configurar_MFA_LinuxMint.sh                   │
  │ 3. Edita el script antes de ejecutar:                   │
  │    DC_IP="IP.DE.TU.SERVIDOR"                            │
  │ 4. Copia users.oath a /etc/security/totp/               │
  │    sudo cp users.oath /etc/security/totp/               │
  │    sudo chmod 600 /etc/security/totp/users.oath         │
  │ 5. Reinicia el cliente Linux Mint                       │
  │ 6. Al iniciar sesion pedira el codigo MFA               │
  └─────────────────────────────────────────────────────────┘

  VERIFICAR EN LINUX (para probar el codigo sin hacer login):
    sudo oathtool --totp -b SECRETO_BASE32_DEL_USUARIO
    (debe mostrar el mismo codigo que Google Authenticator)

  ARCHIVOS GENERADOS EN: $configDir
"@ -ForegroundColor White

Write-Host "[OK] Script_09 completado." -ForegroundColor Green

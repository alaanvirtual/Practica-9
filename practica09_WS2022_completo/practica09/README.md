# PRACTICA 09 — AD Hardening, Auditoría y MFA
## Guía de Despliegue Completa
### Dominio: `practica.local` | Windows Server 2022 | Clientes: Windows 10 y Linux Mint

---

## CONTENIDO DE ESTE PAQUETE

```
practica09_scripts\
├── INICIO_AQUI.bat                        <-- Doble clic para empezar (como Admin)
├── MENU_Practica09_AD_Hardening.ps1       <-- Menu principal interactivo
├── Script_01_Crear_Usuarios_RBAC.ps1      <-- Crea OUs, 4 admins, 5 usuarios
├── Script_02_Delegacion_RBAC.ps1          <-- ACLs RBAC con dsacls
├── Script_03_FGPP.ps1                     <-- Politicas de contraseña FGPP
├── Script_04_Auditoria_Hardening.ps1      <-- Habilita auditpol por GUID
├── Script_05_Reporte_Auditoria.ps1        <-- Reporte eventos 4625
├── Script_06_Instalar_MFA_SecureMFA.ps1   <-- Genera secretos TOTP
├── Script_07_Lockout_MFA.ps1              <-- Configura lockout por MFA
├── Script_08_Tests_Verificacion.ps1       <-- Protocolo de 5 tests
├── Script_09_Configurar_MFA_Clientes.ps1  <-- Genera configs Win10 y Linux
└── README.md                              <-- Esta guia
```

> **Todos los scripts están en UTF-8 con BOM** y tienen saltos de línea CRLF.
> Esto evita el error `Token inesperado` en PowerShell de Windows Server 2022.

---

## PASO 0 — PREPARACIÓN DEL SERVIDOR

### 0.1 Copiar los scripts al servidor

Copia la carpeta completa al servidor (cualquier método):

```
Destino recomendado: C:\Scripts\practica09_scripts\
```

Opciones para copiar:
- **USB / ISO compartida** en tu entorno de VM
- **Carpeta compartida de VMware/VirtualBox** montada en el servidor
- **SCP desde Linux:** `scp -r practica09_scripts/ administrador@IP_SERVIDOR:C:/Scripts/`
- **Desde el cliente Windows 10** vía carpeta compartida `\\SERVIDOR\c$\Scripts\`

### 0.2 Verificar que el dominio existe

Abre PowerShell como Domain Admin y verifica:

```powershell
Get-ADDomain
# Debe mostrar: practica.local
```

Si el servidor no está promovido a DC todavía, no continúes hasta hacerlo.

### 0.3 Verificar que las OUs Cuates y NoCuates existen

```powershell
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName
```

Debes ver:
- `OU=Cuates,OU=Practica,DC=practica,DC=local`
- `OU=NoCuates,OU=Practica,DC=practica,DC=local`

Si no existen, créalas manualmente antes de continuar:

```powershell
New-ADOrganizationalUnit -Name "Practica" -Path "DC=practica,DC=local" -ProtectedFromAccidentalDeletion $false
New-ADOrganizationalUnit -Name "Cuates"   -Path "OU=Practica,DC=practica,DC=local" -ProtectedFromAccidentalDeletion $false
New-ADOrganizationalUnit -Name "NoCuates" -Path "OU=Practica,DC=practica,DC=local" -ProtectedFromAccidentalDeletion $false
```

---

## PASO 1 — EJECUTAR LOS SCRIPTS EN EL SERVIDOR

### Opción A: Menú interactivo (recomendado)

1. Navega a `C:\Scripts\practica09_scripts\`
2. Haz **clic derecho** en `INICIO_AQUI.bat`
3. Selecciona **"Ejecutar como Administrador"**
4. El menú se abrirá automáticamente

En el menú, ejecuta las opciones **en este orden exacto**:

```
[1] Crear admins y usuarios de prueba
[2] Delegacion RBAC con ACLs
[3] Politicas FGPP de contraseña
[4] Hardening de auditoria
[5] Generar TOTP e instalar Credential Provider
[6] Configurar lockout por MFA
[9] Configurar MFA para Win10 y Linux Mint   <-- genera archivos para clientes
[7] Reporte de accesos denegados
[8] Protocolo de tests
```

### Opción B: Ejecución manual por script

Abre PowerShell como Domain Admin y ejecuta:

```powershell
cd C:\Scripts\practica09_scripts

# 1 - Usuarios y OUs
.\Script_01_Crear_Usuarios_RBAC.ps1

# 2 - Delegacion RBAC
.\Script_02_Delegacion_RBAC.ps1

# 3 - FGPP
.\Script_03_FGPP.ps1

# 4 - Auditoria
.\Script_04_Auditoria_Hardening.ps1

# 5 - Secretos TOTP (descarga el MSI antes, ver Paso 2)
.\Script_06_Instalar_MFA_SecureMFA.ps1

# 6 - Lockout
.\Script_07_Lockout_MFA.ps1

# 7 - Config clientes
.\Script_09_Configurar_MFA_Clientes.ps1

# 8 - Reporte (opcional antes de los tests)
.\Script_05_Reporte_Auditoria.ps1

# 9 - Tests
.\Script_08_Tests_Verificacion.ps1
```

---

## PASO 2 — DESCARGAR EL INSTALADOR MFA (ANTES DEL SCRIPT 06)

El Script_06 instala el **Credential Provider SecureMFA** que hace que Windows pida el código TOTP en el login.

1. Desde el servidor, descarga el instalador:
   ```
   https://www.securemfa.com/downloads/mfa-win-otp
   ```

2. Guarda el archivo como:
   ```
   C:\Instaladores\SecureMFA_WinOTP.msi
   ```
   (crea la carpeta `C:\Instaladores\` si no existe)

3. Ejecuta el Script_06.

4. **REINICIA EL SERVIDOR** después del Script_06.

> Si no puedes descargar el MSI, el Script_06 igualmente generará los secretos TOTP.
> El MFA en la pantalla de login del servidor no funcionará, pero sí en los clientes.

---

## PASO 3 — CONFIGURAR CLIENTE WINDOWS 10

Después de ejecutar Script_09 en el servidor, encontrarás en:
```
C:\Reportes\ClienteConfig\
├── Instalar_MFA_Windows10.bat    <-- script de instalacion
└── SecureMFA_WinOTP.msi          <-- (si lo descargaste manualmente)
```

### En el cliente Windows 10:

**3.1 Unir al dominio** (si aún no está unido)

```
Panel de Control > Sistema > Cambiar nombre del equipo/dominio
> Miembro del Dominio: practica.local
> Usuario: Administrador | Contraseña: (la del DC)
> Reiniciar
```

**3.2 Instalar el Credential Provider MFA**

```batch
# Copia el MSI al cliente (USB, carpeta compartida, etc.)
# En el cliente, abre CMD como Administrador:
msiexec /i SecureMFA_WinOTP.msi /quiet /norestart

# O doble clic en Instalar_MFA_Windows10.bat (como Admin)
```

**3.3 Reiniciar el cliente**

**3.4 Configurar Google Authenticator**

1. Desde el servidor, abre `C:\Reportes\TOTP\TOTP_admin_identidad.txt`
2. Copia el **SECRETO BASE32** (cadena de letras mayúsculas y números)
3. En el teléfono, abre **Google Authenticator**
4. Toca **"+"** → **"Ingresar clave de configuración"**
5. Nombre: `admin_identidad`
6. Clave: pega el secreto BASE32
7. Tipo: **Basado en tiempo (TOTP)**
8. Toca **Agregar**

**3.5 Probar el login con MFA**

1. En la pantalla de inicio de sesión de Windows 10
2. Usuario: `PRACTICA\admin_identidad`
3. Contraseña: `Admin@12345!`
4. Aparece campo adicional **"One-Time Password"**
5. Abre Google Authenticator → escribe el código de 6 dígitos
6. **Acceso concedido** ✓

---

## PASO 4 — CONFIGURAR CLIENTE LINUX MINT

Después de ejecutar Script_09, encontrarás en `C:\Reportes\ClienteConfig\`:
```
├── Configurar_MFA_LinuxMint.sh    <-- script bash de configuracion
├── users.oath                     <-- secretos TOTP para PAM
└── Secretos_Para_Linux.txt        <-- referencia de secretos
```

### En el cliente Linux Mint:

**4.1 Copiar los archivos al cliente**

Desde el servidor (PowerShell como Admin):
```powershell
# Compartir la carpeta si no esta compartida:
New-SmbShare -Name "ClienteConfig" -Path "C:\Reportes\ClienteConfig" -FullAccess "Everyone"
```

Desde Linux Mint (terminal):
```bash
# Montar la carpeta compartida del servidor
sudo mkdir -p /mnt/servidor
sudo mount -t cifs //IP_DEL_SERVIDOR/ClienteConfig /mnt/servidor -o username=Administrador

# Copiar los archivos
cp /mnt/servidor/Configurar_MFA_LinuxMint.sh ~/
cp /mnt/servidor/users.oath ~/
```

O simplemente cópialos via USB.

**4.2 Editar la IP del servidor en el script**

```bash
nano ~/Configurar_MFA_LinuxMint.sh
```

Busca esta línea y pon la IP de tu Windows Server 2022:
```bash
DC_IP=""   # <-- Cambia por: DC_IP="192.168.X.X"
```

**4.3 Ejecutar el script como root**

```bash
chmod +x ~/Configurar_MFA_LinuxMint.sh
sudo ~/Configurar_MFA_LinuxMint.sh
```

El script hace automáticamente:
- Instala `sssd`, `realmd`, `krb5`, `oathtool`, `libpam-oath`
- Une Linux Mint al dominio `practica.local`
- Configura SSSD
- Configura PAM para pedir código TOTP
- Crea `/etc/security/totp/users.oath`

**4.4 Copiar el archivo de secretos**

```bash
sudo cp ~/users.oath /etc/security/totp/users.oath
sudo chmod 600 /etc/security/totp/users.oath
```

**4.5 Reiniciar el cliente**

```bash
sudo reboot
```

**4.6 Verificar el código TOTP sin hacer login**

```bash
# Verifica que el código coincide con Google Authenticator:
oathtool --totp -b SECRETO_BASE32_DEL_USUARIO
```

---

## PASO 5 — EJECUTAR LOS 5 TESTS

### TEST 1 — Delegación RBAC (admin_identidad vs admin_storage)

**Desde cliente Windows 10:**

```
1. Inicia sesion como: PRACTICA\admin_identidad | Admin@12345!
2. Abre PowerShell:
   Set-ADAccountPassword -Identity usr_prueba1 `
     -NewPassword (ConvertTo-SecureString "NuevoPass@2025!" -AsPlainText -Force) -Reset
   > Debe FUNCIONAR  [captura de pantalla]

3. Cierra sesion. Inicia como: PRACTICA\admin_storage | Admin@12345!
4. Intenta el mismo comando:
   > Debe dar: "Access is denied" [captura de pantalla]
```

**Desde Linux Mint:**

```bash
kinit admin_identidad@PRACTICA.LOCAL
# Pide la contraseña: Admin@12345!
# Luego prueba el reset (debe funcionar)

kinit admin_storage@PRACTICA.LOCAL
# Intenta el mismo reset -> debe fallar con "Insufficient access rights"
```

**Resultado esperado:** admin_identidad puede resetear contraseñas en OU Cuates/NoCuates. admin_storage recibe ACCESO DENEGADO en cualquier reset de contraseña.

---

### TEST 2 — FGPP (contraseña mínima 12 chars para admins)

**Desde el DC (como Domain Admin):**

```powershell
# Intentar asignar contraseña de 8 chars a admin_identidad
Set-ADAccountPassword -Identity admin_identidad `
    -NewPassword (ConvertTo-SecureString "Test@123" -AsPlainText -Force) -Reset
# RESULTADO ESPERADO: Error de política de contraseña
```

**Desde cliente Windows 10 (como admin_identidad):**

```
Ctrl+Alt+Del > Cambiar contraseña
Escribe: Admin@12345!   (contraseña actual)
Nueva:   Test@123       (solo 8 chars)
> RESULTADO: "La contraseña no cumple los requisitos de complejidad"
```

**Verificar la PSO aplicada:**

```powershell
Get-ADUserResultantPasswordPolicy -Identity "admin_identidad"
# Debe mostrar: MinPasswordLength = 12, LockoutThreshold = 3
```

---

### TEST 3 — MFA Google Authenticator

**Prerrequisitos:** SecureMFA instalado en el cliente y el cliente reiniciado.

```
1. En la pantalla de login del cliente (Windows 10 o Linux Mint)
2. Usuario: admin_identidad  |  Contraseña: Admin@12345!
3. Aparece campo adicional: "One-Time Password" o "Codigo MFA"
4. Abre Google Authenticator en tu telefono
5. Escribe el codigo de 6 digitos
6. RESULTADO: Acceso concedido

CAPTURAS NECESARIAS:
  - Pantalla de login con el campo MFA visible
  - Telefono con Google Authenticator mostrando el codigo
```

**Verificar que el TOTP está guardado en AD:**

```powershell
Get-ADUser admin_identidad -Properties info, extensionAttribute1 | 
    Select-Object SamAccountName, info, extensionAttribute1
# Debe mostrar: info = "TOTP:SECRETOBASE32..."
```

---

### TEST 4 — Bloqueo por intentos MFA fallidos

```
1. En el cliente, ingresa usuario y contraseña CORRECTOS de admin_identidad
2. Cuando pida el codigo MFA, escribe: 000000 (incorrecto)
3. Repite 3 veces (o las que marque el lockout de la FGPP)

4. En el DC, verifica el bloqueo:
   Get-ADUser admin_identidad -Properties LockedOut,BadLogonCount,LockoutTime
   > RESULTADO ESPERADO: LockedOut = True

5. Para desbloquear:
   Unlock-ADAccount -Identity "admin_identidad"
   O usa la opcion [U] del menu principal

CAPTURA NECESARIA:
  - Salida del comando Get-ADUser mostrando LockedOut=True
```

---

### TEST 5 — Reporte de Auditoría (eventos 4625)

**Generar intentos fallidos primero:**

```
1. Intenta iniciar sesion con contraseña incorrecta 3 veces
   (Windows 10 o Linux Mint, cualquier usuario del dominio)
```

**Generar el reporte:**

```powershell
# En el DC:
cd C:\Scripts\practica09_scripts
.\Script_05_Reporte_Auditoria.ps1

# Verificar el archivo generado:
Get-ChildItem C:\Reportes -Filter "Reporte_AccesosDenegados_*.txt"
# Abre el archivo y adjuntalo a tu reporte tecnico
```

```
CAPTURA NECESARIA:
  - Archivo .txt con al menos 1 evento 4625
  - Contenido mostrando: usuario, IP origen, hora, causa del fallo
```

---

## USUARIOS Y CONTRASEÑAS DE REFERENCIA

### Administradores Delegados
| Usuario          | Contraseña   | Rol                                    | OU                                    |
|------------------|--------------|----------------------------------------|---------------------------------------|
| admin_identidad  | Admin@12345! | IAM Operator — gestión de usuarios    | OU=AdminDelegados,DC=practica,DC=local |
| admin_storage    | Admin@12345! | Storage Operator — DENY reset passw.  | OU=AdminDelegados,DC=practica,DC=local |
| admin_politicas  | Admin@12345! | GPO Compliance — lectura dominio      | OU=AdminDelegados,DC=practica,DC=local |
| admin_auditoria  | Admin@12345! | Security Auditor — solo lectura       | OU=AdminDelegados,DC=practica,DC=local |

### Usuarios de Prueba
| Usuario      | Contraseña  | OU                                         |
|--------------|-------------|--------------------------------------------|
| usr_prueba1  | User@12345! | OU=Cuates,OU=Practica,DC=practica,DC=local  |
| usr_prueba2  | User@12345! | OU=Cuates,OU=Practica,DC=practica,DC=local  |
| usr_prueba3  | User@12345! | OU=Cuates,OU=Practica,DC=practica,DC=local  |
| usr_nocuate1 | User@12345! | OU=NoCuates,OU=Practica,DC=practica,DC=local |
| usr_nocuate2 | User@12345! | OU=NoCuates,OU=Practica,DC=practica,DC=local |

---

## COMANDOS ÚTILES EN EL DC

```powershell
# Estado completo de un usuario
Get-ADUser admin_identidad -Properties LockedOut,BadLogonCount,info,extensionAttribute1,PasswordLastSet

# Desbloquear cuenta
Unlock-ADAccount -Identity "admin_identidad"

# PSO resultante para un usuario
Get-ADUserResultantPasswordPolicy -Identity "admin_identidad"

# Ver todas las FGPP
Get-ADFineGrainedPasswordPolicy -Filter * | 
    Select-Object Name, MinPasswordLength, LockoutThreshold, LockoutDuration | 
    Format-Table -AutoSize

# Ultimos eventos de acceso fallido
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625} -MaxEvents 10 |
    Select-Object TimeCreated, Message | Format-List

# Verificar Credential Provider MFA instalado en este servidor
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers" |
    ForEach-Object { (Get-ItemProperty $_.PSPath -Name "(Default)" -EA SilentlyContinue)."(Default)" } |
    Where-Object { $_ }

# Verificar secreto TOTP de un usuario
Get-ADUser admin_identidad -Properties info | Select-Object info

# Ver reportes generados
Get-ChildItem C:\Reportes -Recurse -File | Select-Object Name, LastWriteTime | Format-Table -AutoSize

# Estado del dominio rapido (opcion V del menu)
.\MENU_Practica09_AD_Hardening.ps1
```

---

## CHECKLIST DE AVANCE

### En el Servidor (Windows Server 2022)
- [ ] Scripts copiados a `C:\Scripts\practica09_scripts\`
- [ ] `INICIO_AQUI.bat` ejecutado como Admin (o `Set-ExecutionPolicy RemoteSigned -Force`)
- [ ] **[1]** Script_01 — OUs y usuarios creados
- [ ] **[2]** Script_02 — RBAC con dsacls aplicado
- [ ] **[3]** Script_03 — FGPP PSO_Admins_12chars y PSO_Usuarios_8chars creadas
- [ ] **[4]** Script_04 — auditpol habilitado (11 subcategorías)
- [ ] `SecureMFA_WinOTP.msi` descargado en `C:\Instaladores\`
- [ ] **[5]** Script_06 — secretos TOTP generados en AD y en `C:\Reportes\TOTP\`
- [ ] Servidor reiniciado (para activar Credential Provider)
- [ ] **[6]** Script_07 — lockout configurado (3 intentos admins, 5 usuarios)
- [ ] **[7]** Script_09 — archivos de config generados en `C:\Reportes\ClienteConfig\`

### En Cliente Windows 10
- [ ] Cliente unido al dominio `practica.local`
- [ ] `SecureMFA_WinOTP.msi` instalado (con `Instalar_MFA_Windows10.bat`)
- [ ] Cliente reiniciado
- [ ] Pantalla de login muestra campo MFA (captura tomada)
- [ ] Google Authenticator configurado con secreto del usuario
- [ ] Login exitoso con MFA

### En Cliente Linux Mint
- [ ] `Configurar_MFA_LinuxMint.sh` copiado al cliente
- [ ] `users.oath` copiado al cliente
- [ ] `DC_IP` editado en el script bash con la IP del servidor
- [ ] Script ejecutado como root: `sudo ./Configurar_MFA_LinuxMint.sh`
- [ ] `users.oath` copiado a `/etc/security/totp/` con permisos 600
- [ ] Cliente reiniciado
- [ ] Login pide codigo MFA

### Tests del Protocolo
- [ ] **Test 1A** — admin_identidad resetea contraseña en OU Cuates (ÉXITO) + captura
- [ ] **Test 1B** — admin_storage intenta lo mismo (ACCESO DENEGADO) + captura
- [ ] **Test 2**  — Contraseña 8 chars rechazada para admin_identidad + captura
- [ ] **Test 3**  — Login pide código Google Authenticator + captura
- [ ] **Test 4**  — 3 intentos fallidos bloquean la cuenta 30 min + captura Get-ADUser
- [ ] **Test 5**  — Script_05 genera archivo .txt con eventos 4625 + archivo adjunto

---

## SOLUCIÓN DE ERRORES COMUNES

| Error | Causa | Solución |
|-------|-------|----------|
| `Token inesperado` al ejecutar .ps1 | Encoding incorrecto | Los scripts ya están en UTF-8 BOM. Si el error persiste, ábrelos en Notepad++ y guárdalos como UTF-8 con BOM |
| `OU=Cuates no encontrada` | OU no existe en el dominio | Ejecuta el bloque de New-ADOrganizationalUnit del Paso 0.3 |
| `PSO no encontrada` en Script_07 | Script_03 no ejecutado | Ejecuta Script_03 primero |
| `0 eventos 4625` en Script_05 | Sin intentos fallidos aún | Haz 3 logins fallidos y luego ejecuta Script_05 |
| MFA no aparece en login W10 | MSI no instalado o no reiniciado | Instala el .msi y reinicia el cliente |
| MFA no aparece en Linux Mint | PAM no configurado | Ejecuta Script_09 en el DC, luego el script bash en el cliente |
| `Secreto TOTP` no en AD | Script_06 no ejecutado | Ejecuta Script_06; verifica atributo `info` del usuario |
| Login Linux Mint sin MFA | `users.oath` no copiado | Copia `users.oath` a `/etc/security/totp/` y `chmod 600` |
| `realm join` falla en Linux | DNS no apunta al DC | En Linux: `sudo nano /etc/resolv.conf` → agrega `nameserver IP_DEL_DC` |
| `kinit` falla en Linux | Kerberos no configurado | Verifica `/etc/krb5.conf` tenga `default_realm = PRACTICA.LOCAL` |
| `dsacls` no encontrado | Herramientas AD no instaladas | `Add-WindowsFeature RSAT-AD-Tools` en PowerShell del DC |

---

## ARQUITECTURA DE LA PRÁCTICA

```
┌─────────────────────────────────────────────────────────────┐
│              Windows Server 2022 — DC practica.local         │
│                                                             │
│  OU=AdminDelegados                                          │
│  ├── admin_identidad   (IAM Operator, PSO 12chars)         │
│  ├── admin_storage     (Storage Op., DENY reset passw.)    │
│  ├── admin_politicas   (GPO Compliance)                     │
│  └── admin_auditoria   (Read-only + Event Log Readers)     │
│                                                             │
│  OU=Practica                                                │
│  ├── OU=Cuates                                              │
│  │   ├── usr_prueba1, usr_prueba2, usr_prueba3             │
│  └── OU=NoCuates                                            │
│      ├── usr_nocuate1, usr_nocuate2                        │
│                                                             │
│  FGPP:  PSO_Admins_12chars (prec.10) | PSO_Users_8chars    │
│  Audit: auditpol 11 subcategorias   | Log: Event ID 4625   │
│  TOTP:  Secretos en atributo 'info' y 'extensionAttribute1'│
└─────────────────────────────────────────────────────────────┘
         |                              |
         v                              v
┌─────────────────┐          ┌──────────────────────┐
│  Windows 10     │          │  Linux Mint          │
│                 │          │                      │
│  SecureMFA      │          │  SSSD + Realmd       │
│  WinOTP         │          │  PAM + pam_oath      │
│  Credential     │          │  oathtool TOTP       │
│  Provider       │          │  /etc/security/totp/ │
│                 │          │                      │
│  Login:         │          │  Login:              │
│  user+pass+TOTP │          │  user+pass+TOTP      │
└─────────────────┘          └──────────────────────┘
```

---

## ARCHIVOS GENERADOS DURANTE LA PRÁCTICA

| Ruta en el servidor | Descripción |
|---------------------|-------------|
| `C:\Reportes\TOTP\TOTP_<usuario>.txt` | Secreto TOTP + URI OTP + instrucciones para Google Auth |
| `C:\Reportes\ClienteConfig\Instalar_MFA_Windows10.bat` | Script de instalación para el cliente W10 |
| `C:\Reportes\ClienteConfig\Configurar_MFA_LinuxMint.sh` | Script bash para Linux Mint |
| `C:\Reportes\ClienteConfig\users.oath` | Archivo de secretos TOTP para PAM en Linux |
| `C:\Reportes\ClienteConfig\Secretos_Para_Linux.txt` | Referencia de secretos para copiar en el script bash |
| `C:\Reportes\Reporte_AccesosDenegados_FECHA.txt` | Reporte de eventos 4625 (Test 5) |

---

*Práctica 09 — Administración de Redes*  
*Dominio: practica.local | Windows Server 2022*

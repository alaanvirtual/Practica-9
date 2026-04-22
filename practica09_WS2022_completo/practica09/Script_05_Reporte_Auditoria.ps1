# ============================================================
#  Script_05_Reporte_Auditoria.ps1
#  Extrae los ultimos 10 eventos ID 4625 (acceso denegado)
#  y los exporta a C:\Reportes\Reporte_AccesosDenegados_<fecha>.txt
#  Puede ejecutarlo admin_auditoria (miembro de Event Log Readers)
# ============================================================

$outputDir  = "C:\Reportes"
$fechaHoy   = Get-Date -Format "yyyy-MM-dd_HHmm"
$outputFile = "$outputDir\Reporte_AccesosDenegados_$fechaHoy.txt"

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

Write-Host "`n[INFO] Extrayendo eventos ID 4625 del log de seguridad..." -ForegroundColor Yellow

$eventos = Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    Id      = 4625
} -MaxEvents 10 -ErrorAction SilentlyContinue

# Encabezado del reporte
$linea = "=" * 64
@"
$linea
  REPORTE DE ACCESOS DENEGADOS
  Generado : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  Servidor : $($env:COMPUTERNAME)
  Dominio  : $($env:USERDOMAIN)
$linea
"@ | Out-File $outputFile -Encoding UTF8

if (-not $eventos) {
    $msg = "[WARN] No se encontraron eventos 4625 en el log de seguridad.`n" +
           "       Asegurate de haber ejecutado Script_04 y de haber generado`n" +
           "       al menos un intento de acceso fallido."
    $msg | Out-File $outputFile -Append -Encoding UTF8
    Write-Host $msg -ForegroundColor Yellow
    exit
}

$contador = 1
foreach ($ev in $eventos) {
    $xml  = [xml]$ev.ToXml()
    $data = $xml.Event.EventData.Data

    $subStatus    = ($data | Where-Object { $_.Name -eq "SubStatus" })."#text"
    $targetUser   = ($data | Where-Object { $_.Name -eq "TargetUserName" })."#text"
    $targetDomain = ($data | Where-Object { $_.Name -eq "TargetDomainName" })."#text"
    $workstation  = ($data | Where-Object { $_.Name -eq "WorkstationName" })."#text"
    $ipAddress    = ($data | Where-Object { $_.Name -eq "IpAddress" })."#text"
    $logonType    = ($data | Where-Object { $_.Name -eq "LogonType" })."#text"

    $causa = switch ($subStatus) {
        "0xC000006A" { "Contrasena incorrecta" }
        "0xC0000064" { "Usuario no existe" }
        "0xC000006F" { "Fuera de horario permitido" }
        "0xC0000070" { "Workstation no autorizada" }
        "0xC0000072" { "Cuenta deshabilitada" }
        "0xC000006E" { "Cuenta bloqueada (Lockout)" }
        "0xC0000193" { "Cuenta expirada" }
        default      { "SubStatus: $subStatus" }
    }

    $logonTypeStr = switch ($logonType) {
        "2"  { "Interactivo (consola)" }
        "3"  { "Red (SMB/compartidos)" }
        "4"  { "Batch" }
        "5"  { "Servicio" }
        "7"  { "Desbloqueo de pantalla" }
        "10" { "RDP / Remoto interactivo" }
        default { "Tipo $logonType" }
    }

    $bloque = @"

[$contador] Evento #$($ev.RecordId) - $($ev.TimeCreated)
    Usuario       : $targetDomain\$targetUser
    Causa         : $causa
    Tipo de logon : $logonTypeStr
    Workstation   : $workstation
    IP origen     : $ipAddress
$(("-" * 64))
"@
    $bloque | Out-File $outputFile -Append -Encoding UTF8
    Write-Host "  [$contador] $($ev.TimeCreated) | $targetDomain\$targetUser | $causa"
    $contador++
}

@"

$linea
  FIN DEL REPORTE
  Total eventos exportados: $($eventos.Count)
  Archivo: $outputFile
$linea
"@ | Out-File $outputFile -Append -Encoding UTF8

Write-Host "`n[OK] Reporte generado: $outputFile" -ForegroundColor Green
Invoke-Item $outputDir

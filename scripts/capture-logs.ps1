# Captura continua de logs del stack a archivo durante la ventana de prueba
# con el cliente. Ejecutar en una terminal aparte y dejar corriendo (Ctrl+C para parar).
# Cuando el cliente reporte "me salio un error", buscar por hora en logs/stack_*.log.
param(
  [string]$LogDir = "D:\Proyectos\medestetica-saas\logs"
)

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$stamp = Get-Date -Format "yyyy-MM-dd_HHmm"
$file = Join-Path $LogDir "stack_$stamp.log"

Write-Output "Capturando logs de todos los servicios en: $file"
Write-Output "(Ctrl+C para detener)"

docker compose -f "D:\Proyectos\medestetica-saas\docker-compose.yml" logs -f --timestamps 2>&1 |
  Tee-Object -FilePath $file

<#
  Crea (o reutiliza) una rama nueva y guarda ahí los cambios locales
  actuales, SIN tocar la rama en la que estabas ni subir nada a ella.

  Nombre de la rama:
    Se lee de scripts\branch-name.txt (junto a este script). Edita ese
    archivo con el nombre que quieras antes de correr el script.

  Mensaje de commit:
    - Si pasas -Message, se usa ese texto tal cual.
    - Si no, se lee de scripts\commit-message.txt (mismo archivo que usa
      actualizar.ps1).
    - Si tampoco existe, se usa una marca de tiempo por defecto.

  Ruta del repo:
    $PSScriptRoot es la carpeta de ESTE archivo .ps1 (siempre
    "<repo>\scripts"). Subir un nivel da la raíz del repo, así que el
    script funciona igual sin importar desde dónde lo invoques.

  Qué hace, en orden:
    1. Guarda el nombre de la rama actual.
    2. Crea la rama nueva desde el punto actual (o la reutiliza si ya existe).
    3. Commitea ahí los cambios pendientes.
    4. Sube esa rama nueva a GitHub (git push -u).
    5. Vuelve a la rama original, que queda intacta y sin subir cambios.

    Si cualquiera de los pasos 3 o 4 falla, el script igual vuelve a la
    rama original antes de terminar (no te deja varado en la rama nueva a
    medio hacer), y avisa con un mensaje claro qué falló.

  Uso:
    .\scripts\nuevarama.ps1
    .\scripts\nuevarama.ps1 -Message "Prueba de nueva funcionalidad"
    .\scripts\nuevarama.ps1 -Remote origin
#>
param(
    [string]$Message,
    [string]$Remote = "origin"
)

$ErrorActionPreference = "Stop"

# Este script vive en <repo>/scripts, así que la raíz del repo es un nivel arriba.
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

. (Join-Path $PSScriptRoot "_common.ps1")

# 1) Nombre de la rama: obligatorio, viene de branch-name.txt.
$branchFile = Join-Path $PSScriptRoot "branch-name.txt"
if (-not (Test-Path $branchFile)) {
    throw "No se encontró $branchFile. Crea ese archivo con el nombre de la rama a usar."
}
$newBranch = (Get-Content -Path $branchFile -Raw).Trim()
if (-not $newBranch) {
    throw "$branchFile está vacío. Escribe ahí el nombre de la rama a crear."
}

# 2) Mensaje de commit: -Message, si no commit-message.txt, si no una marca de tiempo.
if (-not $Message) {
    $msgFile = Join-Path $PSScriptRoot "commit-message.txt"
    if (Test-Path $msgFile) {
        $Message = (Get-Content -Path $msgFile -Raw).Trim()
    }
}
if (-not $Message) {
    $Message = "Actualizacion $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
}

# 3) Verificar que hay cambios (staged, modificados o nuevos); si no hay nada, no tiene sentido crear la rama.

$pending = git status --porcelain
if (-not $pending) {
    Write-Host "No hay cambios locales para guardar. No se crea ninguna rama."
    exit 0
}

$originalBranch = git rev-parse --abbrev-ref HEAD

Write-Host "Repositorio      : $repoRoot"
Write-Host "Rama actual      : $originalBranch"
Write-Host "Rama nueva       : $newBranch"
Write-Host "Remoto           : $Remote"
Write-Host "Mensaje          : $Message"
Write-Host ""
Write-Host "Archivos a commitear:"
$pending | ForEach-Object { Write-Host "  $_" }
Write-Host ""

try {
    # 4) Crear la rama nueva (o cambiar a ella si ya existe) sin perder lo ya agregado al índice.
    $branchExists = git branch --list $newBranch
    if ($branchExists) {
        Write-Host "La rama '$newBranch' ya existe localmente; se usará esa."
        Invoke-Git checkout $newBranch
    } else {
        Invoke-Git checkout -b $newBranch
    }

    # 5) Agregar todos los cambios pendientes y commitear en la rama nueva.
    Invoke-Git add -A
    Invoke-Git commit -m $Message

    # 6) Subir la rama nueva a GitHub (no toca la rama original en el remoto).
    Invoke-Git push -u $Remote $newBranch

    Write-Host ""
    Write-Host "Listo: cambios guardados y subidos en '$newBranch'."
}
finally {
    # 7) Volver siempre a la rama original, incluso si algo de arriba falló,
    #    para no dejarte varado en la rama nueva a medio terminar.
    $currentBranch = git rev-parse --abbrev-ref HEAD
    if ($currentBranch -ne $originalBranch) {
        git checkout $originalBranch | Out-Null
        Write-Host "Estás de vuelta en '$originalBranch'."
    }
}

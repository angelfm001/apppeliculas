<#
  Cambia a la rama indicada en scripts\branch-name.txt (junto a este script).

  Si la rama:
    - Ya existe localmente        -> simplemente hace checkout.
    - Existe solo en el remoto    -> crea una rama local que la sigue (tracking).
    - No existe ni local ni remoto -> avisa y no hace nada (usa nuevarama.ps1
      si lo que quieres es crearla).

  Ruta del repo:
    $PSScriptRoot es la carpeta de ESTE archivo .ps1 (siempre
    "<repo>\scripts"). Subir un nivel da la raíz del repo, así que el
    script funciona igual sin importar desde dónde lo invoques.

  Uso:
    .\scripts\cambiorama.ps1
    .\scripts\cambiorama.ps1 -Remote origin
#>
param(
    [string]$Remote = "origin"
)

$ErrorActionPreference = "Stop"

# Este script vive en <repo>/scripts, así que la raíz del repo es un nivel arriba.
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

. (Join-Path $PSScriptRoot "_common.ps1")

$branchFile = Join-Path $PSScriptRoot "branch-name.txt"
if (-not (Test-Path $branchFile)) {
    throw "No se encontró $branchFile. Crea ese archivo con el nombre de la rama a usar."
}
$branch = (Get-Content -Path $branchFile -Raw).Trim()
if (-not $branch) {
    throw "$branchFile está vacío. Escribe ahí el nombre de la rama a la que quieres cambiar."
}

$originalBranch = git rev-parse --abbrev-ref HEAD
Write-Host "Repositorio  : $repoRoot"
Write-Host "Rama actual  : $originalBranch"
Write-Host "Rama destino : $branch"
Write-Host ""

if ($branch -eq $originalBranch) {
    Write-Host "Ya estás en '$branch'. No hay nada que cambiar."
    exit 0
}

# Si hay cambios sin commitear, git checkout los conserva mientras no choquen
# con la rama destino; si chocan, git avisa y no cambia de rama (no se pierde nada).
$localExists = git branch --list $branch
if ($localExists) {
    Invoke-Git checkout $branch
} else {
    Write-Host "Buscando '$branch' en el remoto '$Remote'..."
    Invoke-Git fetch $Remote

    $remoteExists = git branch -r --list "$Remote/$branch"
    if ($remoteExists) {
        Invoke-Git checkout -b $branch --track "$Remote/$branch"
    } else {
        Write-Host "La rama '$branch' no existe ni localmente ni en '$Remote'."
        Write-Host "Usa scripts\nuevarama.ps1 si quieres crearla con tus cambios actuales."
        exit 1
    }
}

Write-Host ""
Write-Host "Listo: ahora estás en '$branch'."

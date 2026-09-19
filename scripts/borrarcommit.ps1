<#
  Borra el ÚLTIMO commit de una rama en GitHub (remoto), SIN tocar nada
  en local: tu HEAD, tu working tree, tu índice y tu historial local
  quedan exactamente igual que antes de correr esto.

  Cómo funciona:
    En vez de hacer "git reset" local + push, lo cual sí movería tu rama
    local, este script empuja directamente el commit PADRE del último
    commit remoto como nuevo tope de la rama remota:

      git push <remote> <padre-del-ultimo-commit>:refs/heads/<rama> --force

    Esto reescribe el historial de esa rama en GitHub (equivale a un
    "git reset --hard HEAD~1" + push --force, pero hecho sin mover tu
    rama local ni un milímetro).

  Importante:
    - Esto es un force-push: reescribe historia en GitHub. Si alguien
      más ya bajó ese commit, su repo quedará desincronizado y tendrá
      que resolverlo a mano.
    - Si la rama remota tiene protección contra force-push (común en
      main/master en GitHub), el push será rechazado por GitHub y no
      pasará nada (no hay riesgo de "medio aplicarlo").
    - Solo funciona si la rama tiene 2+ commits. Si el commit a borrar
      es el único que existe, no hay "padre" al que volver; habría que
      borrar la rama entera, y este script no lo hace.

  Ruta del repo:
    $PSScriptRoot es la carpeta de ESTE archivo .ps1 (siempre
    "<repo>\scripts"). Subir un nivel da la raíz del repo, así que el
    script funciona igual sin importar desde dónde lo invoques.

  Uso:
    .\scripts\borrarcommit.ps1
    .\scripts\borrarcommit.ps1 -Branch ClinicaPort
    .\scripts\borrarcommit.ps1 -Branch main -Remote origin
    .\scripts\borrarcommit.ps1 -Force              # sin preguntar confirmación
#>
param(
    [string]$Remote = "origin",
    [string]$Branch,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Este script vive en <repo>/scripts, así que la raíz del repo es un nivel arriba.
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

# Si no se pasó -Branch, se usa la rama local actual.
if (-not $Branch) {
    $Branch = git rev-parse --abbrev-ref HEAD
}

Write-Host "Repositorio : $repoRoot"
Write-Host "Remoto      : $Remote"
Write-Host "Rama        : $Branch"
Write-Host ""

# 1) Traer el estado real de esa rama en GitHub (no nos fiamos de una caché vieja).
Write-Host "Consultando el último commit de '$Branch' en '$Remote'..."
git fetch $Remote $Branch

$remoteRef = "refs/remotes/$Remote/$Branch"
git rev-parse --verify --quiet $remoteRef *> $null
if ($LASTEXITCODE -ne 0) {
    throw "No existe la rama '$Branch' en el remoto '$Remote'."
}

# 2) Commit actual (el que se va a borrar de GitHub) y su padre (a donde va a quedar la rama).
$lastCommit = git log -1 --format="%H|%s" $remoteRef
$lastHash, $lastSubject = $lastCommit -split '\|', 2

git rev-parse --verify --quiet "$remoteRef~1" *> $null
if ($LASTEXITCODE -ne 0) {
    throw "'$Branch' en '$Remote' solo tiene un commit; no hay un commit padre al que volver. Este script no puede vaciar la rama."
}
$parentHash = git rev-parse "$remoteRef~1"
$parentCommit = git log -1 --format="%H|%s" $parentHash
$parentHashFull, $parentSubject = $parentCommit -split '\|', 2

Write-Host "Se va a borrar de GitHub:"
Write-Host "  $lastHash  $lastSubject"
Write-Host "La rama '$Branch' en '$Remote' quedará apuntando a:"
Write-Host "  $parentHashFull  $parentSubject"
Write-Host ""
Write-Host "Tu repositorio LOCAL no se toca en absoluto (ni HEAD, ni archivos, ni historial)."
Write-Host ""

# 3) Confirmación. Si la rama es main/master pedimos escribir "SI" tal cual, por ser rama protegida típica.
if (-not $Force) {
    if ($Branch -in @("main", "master")) {
        Write-Host "ATENCION: '$Branch' suele ser la rama principal del repo." -ForegroundColor Yellow
        $answer = Read-Host "Escribe SI (mayusculas) para confirmar que quieres reescribir '$Remote/$Branch'"
        if ($answer -ne "SI") {
            Write-Host "Cancelado. No se hizo ningún cambio."
            exit 0
        }
    } else {
        $answer = Read-Host "¿Confirmas? Esto reescribe '$Remote/$Branch' en GitHub (s/N)"
        if ($answer -notin @("s", "S", "si", "Si", "SI")) {
            Write-Host "Cancelado. No se hizo ningún cambio."
            exit 0
        }
    }
}

# 4) Empujar el commit padre como nuevo tope de la rama remota.
#    Nota: esto NUNCA toca tu rama local, solo mueve el puntero de la rama en GitHub.
git push $Remote "${parentHashFull}:refs/heads/$Branch" --force

Write-Host ""
Write-Host "Listo: '$Remote/$Branch' ya no tiene el commit '$lastHash'."
Write-Host "Tu repositorio local sigue exactamente igual que antes."

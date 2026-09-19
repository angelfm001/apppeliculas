<#
  Sincroniza los cambios locales de este proyecto con GitHub:
  https://github.com/angelfm001/apppeliculas.git

  Hace, en orden: fetch -> add -> commit (si hay cambios) -> pull --rebase
  (si la rama ya existe en el remoto) -> push. Cada paso se detiene con
  un mensaje claro si falla, en vez de seguir adelante como si nada
  (ver Invoke-Git en _common.ps1).

  A diferencia de la versión anterior, NO sale temprano cuando el árbol
  está limpio: si ya tienes commits locales por delante del remoto,
  igual hace pull --rebase (si aplica) y push. Solo dice
  "Nada que subir" cuando no hay nada nuevo ni en el árbol ni en commits.

  Si la rama todavía no existe en el remoto (repo vacío o rama nueva),
  se salta el "pull --rebase" (fallaría con "no such ref") y hace
  directamente "push -u".

  Si "pull --rebase" encuentra conflictos, el script aborta el rebase
  automáticamente (git rebase --abort) para dejar el repositorio en un
  estado limpio y utilizable, y te avisa que hace falta sincronizar a mano
  en vez de intentar el push igual. Tu commit local nunca se pierde: sigue
  intacto y accesible aunque el rebase se aborte.

  Mensaje de commit:
    - Si pasas -Message, se usa ese texto tal cual.
    - Si no, se lee de scripts\commit-message.txt (junto a este script).
    - Si ese archivo no existe o está vacío, se usa una marca de tiempo por defecto.

  Ruta del repo:
    $PSScriptRoot es la carpeta donde vive ESTE archivo .ps1 (siempre,
    sin importar desde dónde lo invoques). Como el script está en
    "<repo>\scripts", subir un nivel con Split-Path -Parent da la raíz
    del repo. Así el script funciona igual si lo corres desde
    "C:\...\Clinica" o desde "C:\...\Clinica\scripts", o desde cualquier
    otra carpeta.

  Rama:
    Si no pasas -Branch, se usa la rama en la que estés parado actualmente
    (no siempre "main"). Así el pull --rebase y el push actúan sobre tu
    rama actual y no sobre otra por error.

  Uso:
    .\scripts\actualizar.ps1
    .\scripts\actualizar.ps1 -Message "Filtros de pacientes y notificaciones en tiempo real"
    .\scripts\actualizar.ps1 -Branch main -Remote origin
#>
param(
    [string]$Message,
    [string]$Remote = "origin",
    [string]$Branch
)

$ErrorActionPreference = "Stop"

# Este script vive en <repo>/scripts, así que la raíz del repo es un nivel arriba.
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

. (Join-Path $PSScriptRoot "_common.ps1")

# Si no se pasó -Branch, se usa la rama actual (evita pull/push contra la rama equivocada).
if (-not $Branch) {
    $Branch = git rev-parse --abbrev-ref HEAD
}

# Si no se pasó -Message, se busca scripts\commit-message.txt.
if (-not $Message) {
    $msgFile = Join-Path $PSScriptRoot "commit-message.txt"
    if (Test-Path $msgFile) {
        $Message = (Get-Content -Path $msgFile -Raw).Trim()
    }
}
if (-not $Message) {
    $Message = "Actualizacion $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
}

Write-Host "Repositorio : $repoRoot"
Write-Host "Remoto      : $Remote"
Write-Host "Rama        : $Branch"
Write-Host "Mensaje     : $Message"
Write-Host ""

# 1) Traer el estado remoto antes de tocar nada.
Write-Host "Sincronizando referencias remotas..."
Invoke-Git fetch $Remote

# Saber si la rama ya existe en el remoto. Si no existe (repo vacío o
# rama nueva), el pull --rebase fallaría con "no such ref", así que se salta.
$remoteRef = "$Remote/$Branch"
$lsRemote = git ls-remote --heads $Remote $Branch
$remoteExists = (-not (-not $lsRemote -or $lsRemote.Trim() -eq ""))
$remoteTrackingExists = $false
& git show-ref --verify --quiet "refs/remotes/$remoteRef"
if ($LASTEXITCODE -eq 0) { $remoteTrackingExists = $true }

# 2) Preparar los cambios locales (se excluye la config local de Claude Code).
Invoke-Git add -A -- ':!.claude'

$staged = git diff --cached --name-only
$didCommit = $false
if ($staged) {
    Write-Host "Archivos a commitear:"
    $staged | ForEach-Object { Write-Host "  $_" }
    Write-Host ""

    # 3) Commit.
    Invoke-Git commit -m $Message
    $didCommit = $true
}
else {
    Write-Host "No hay cambios en el árbol para commitear."
}

# 4) Ver si hay commits locales por delante del remoto. Si el remoto no
#    tiene la rama, todo el historial local está pendiente de subir.
$ahead = 0
$behind = 0
if ($remoteTrackingExists) {
    $ahead = [int](git rev-list --count "$remoteRef..HEAD")
    $behind = [int](git rev-list --count "HEAD..$remoteRef")
}
elseif ($remoteExists) {
    # La rama existe en el remoto pero aún no tenemos la ref local
    # (fetch recién hecho debería haberla creado, por seguridad se asume
    # que hay que sincronizar).
    $behind = 1
}
else {
    $ahead = [int](git rev-list --count HEAD)
}

if (-not $didCommit -and $ahead -eq 0 -and $behind -eq 0) {
    Write-Host "Nada que subir: ni cambios en el árbol ni commits pendientes."
    exit 0
}
if (-not $didCommit -and $ahead -gt 0) {
    Write-Host "Hay $ahead commit(s) local(es) pendiente(s) de subir."
}

# 5) Traer y aplicar el histórico remoto por si alguien más subió cambios,
#    antes de intentar el push (evita un push rechazado). Se salta si la
#    rama aún no existe en el remoto. Si hay conflictos, no seguimos
#    adelante: abortamos el rebase para dejar el repo limpio (tu commit
#    de arriba queda intacto, solo falta sincronizar a mano).
if ($remoteExists -and $remoteTrackingExists) {
    & git pull --rebase $Remote $Branch
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "El 'pull --rebase' encontró conflictos y no se completó." -ForegroundColor Yellow
        Write-Host "Abortando el rebase para dejar el repositorio en un estado limpio..." -ForegroundColor Yellow
        git rebase --abort 2>$null
        throw "No se pudo sincronizar con '$Remote/$Branch' por conflictos. Tu commit local sigue intacto. Resuélvelo a mano (por ejemplo: git pull --rebase $Remote $Branch) y vuelve a correr este script, o pide ayuda antes de reintentar. No se hizo push."
    }
}
elseif (-not $remoteExists) {
    Write-Host "La rama '$Branch' no existe aún en '$Remote': se omitirá el pull y se creará con el push."
}

# 6) Subir. Con -u la primera vez para dejar el upstream configurado
#    (evita el aviso "upstream is gone" / "no upstream configured").
if (-not $remoteExists) {
    Invoke-Git push -u $Remote $Branch
}
else {
    Invoke-Git push $Remote $Branch
}

Write-Host ""
Write-Host "Listo: cambios subidos a $Remote/$Branch."

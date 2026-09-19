<#
  Borra el PRIMER commit (raíz) de una rama, reescribiendo su historial,
  en local y en GitHub.

  A diferencia de borrarcommit.ps1 (que solo mueve el puntero remoto al
  commit padre sin tocar nada local), aquí no hay truco remoto posible:
  quitar el primer commit cambia TODOS los hashes siguientes. Por eso el
  script hace dos cosas:

    1. Reescribe la rama LOCAL sin el commit raíz, en dos pasos:
       a) crea una rama huérfana temporal con el ÁRBOL del 2º commit y lo
          commitea como nueva raíz (mismo contenido, mensaje y autor);
       b) re-aplica los commits 3..n sobre esa nueva raíz. Como el árbol
          base es idéntico al original, siempre entra limpio.
       (Un "rebase -i --root" descartando el pick NO sirve: re-aplicar el
       diff del 2º commit sobre un árbol vacío choca con modify/delete si
       el 2º commit tocaba archivos de la raíz.)
    2. Sube el resultado a GitHub con push --force-with-lease (salvo que
       pases -NoPush).

  Requisitos:
    - El árbol de trabajo debe estar limpio (sin cambios sin commitear),
      porque el rebase lo exige.
    - La rama debe tener 2+ commits. Si solo tiene uno, borrar el primero
      equivale a vaciar/borrar la rama, y este script no lo hace (borra la
      rama a mano en ese caso).

  Importante:
    - Esto reescribe historia. Quien ya tenga esta rama (local o clonada)
      deberá volver a clonarla o reajustarla a mano.
    - Después de correr esto NO uses actualizar.ps1 para subir: ese script
      hace pull --rebase y duplicaría commits contra el historial viejo.
      El push con force ya lo hace este script (o hazlo a mano).
    - Si la rama remota está protegida contra force-push (común en main),
      el push será rechazado por GitHub. El rebase local YA habrá ocurrido;
      más abajo se indica cómo volver atrás con el hash anterior.
    - Antes del push se muestra el hash del HEAD anterior: con
      "git reset --hard <hash-anterior>" puedes deshacer el rebase local
      mientras no hayas subido nada.

  Ruta del repo:
    $PSScriptRoot es la carpeta de ESTE archivo .ps1 (siempre
    "<repo>\scripts"). Subir un nivel da la raíz del repo, así que el
    script funciona igual sin importar desde dónde lo invoques.

  Uso:
    .\scripts\borrarprimercommit.ps1
    .\scripts\borrarprimercommit.ps1 -Branch main -Remote origin
    .\scripts\borrarprimercommit.ps1 -NoPush   # solo reescribe local, no sube
    .\scripts\borrarprimercommit.ps1 -Force    # sin preguntar confirmación
#>
param(
    [string]$Remote = "origin",
    [string]$Branch,
    [switch]$NoPush,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Este script vive en <repo>/scripts, así que la raíz del repo es un nivel arriba.
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

. (Join-Path $PSScriptRoot "_common.ps1")

# Si no se pasó -Branch, se usa la rama local actual.
if (-not $Branch) {
    $Branch = git rev-parse --abbrev-ref HEAD
}

Write-Host "Repositorio : $repoRoot"
Write-Host "Remoto      : $Remote"
Write-Host "Rama        : $Branch"
Write-Host ""

# 1) Traer el estado remoto antes de tocar nada.
Write-Host "Sincronizando referencias remotas..."
Invoke-Git fetch $Remote

# 2) Pararse en la rama objetivo (con el árbol limpio el checkout es seguro).
$current = git rev-parse --abbrev-ref HEAD
if ($current -ne $Branch) {
    if (git branch --list $Branch) {
        Invoke-Git checkout $Branch
    }
    elseif (git branch -r --list "$Remote/$Branch") {
        Invoke-Git checkout -b $Branch --track "$Remote/$Branch"
    }
    else {
        throw "La rama '$Branch' no existe ni localmente ni en '$Remote'."
    }
}

# 3) El rebase exige un árbol limpio en archivos rastreados. Los archivos
#    nuevos sin rastrear (untracked, como este mismo script antes de su
#    primer commit) NO estorban al rebase, así que se ignoran a propósito:
#    si no, el script se bloquearía a sí mismo solo por existir.
$dirty = git status --porcelain --untracked-files=no
if ($dirty) {
    throw "Hay cambios sin commitear. Commitea o descarta antes de reescribir el historial (el rebase lo exige)."
}

# 4) La rama debe tener 2+ commits; localizar la raíz y el que será la nueva raíz.
$count = [int](git rev-list --count HEAD)
if ($count -lt 2) {
    throw "La rama '$Branch' solo tiene un commit; borrarlo equivale a vaciar la rama. Este script no lo hace: borra la rama a mano si eso es lo que quieres."
}
$rootHash = git rev-list --max-parents=0 HEAD
$rootSubject = git log -1 --format="%s" $rootHash
$secondHash = git log --format="%H" --reverse "$rootHash..HEAD" | Select-Object -First 1
$secondSubject = git log -1 --format="%s" $secondHash
$oldHead = git rev-parse HEAD

Write-Host "Se va a ELIMINAR el primer commit de '$Branch':"
Write-Host "  $rootHash  $rootSubject"
Write-Host "El nuevo primer commit será:"
Write-Host "  $secondHash  $secondSubject"
Write-Host "Commits: $count -> $($count - 1). TODOS los hashes siguientes cambiarán."
Write-Host "Esto reescribe historia: quien ya tenga esta rama deberá volver a clonarla o reajustarla a mano."
if ($NoPush) {
    Write-Host "NO se hará push (-NoPush). Recuerda: no uses actualizar.ps1 después; sube a mano con 'git push --force-with-lease $Remote $Branch'."
}
else {
    Write-Host "Después se subirá con push --force-with-lease a '$Remote/$Branch'."
}
Write-Host ""

# 5) Confirmación. Si la rama es main/master pedimos escribir "SI" tal cual.
if (-not $Force) {
    if ($Branch -in @("main", "master")) {
        Write-Host "ATENCION: '$Branch' suele ser la rama principal del repo." -ForegroundColor Yellow
        $answer = Read-Host "Escribe SI (mayusculas) para confirmar que quieres borrar su primer commit y reescribirla"
        if ($answer -ne "SI") {
            Write-Host "Cancelado. No se hizo ningún cambio."
            exit 0
        }
    } else {
        $answer = Read-Host "¿Confirmas? Esto reescribe '$Branch' en local y en '$Remote/$Branch' (s/N)"
        if ($answer -notin @("s", "S", "si", "Si", "SI")) {
            Write-Host "Cancelado. No se hizo ningún cambio."
            exit 0
        }
    }
}

# 6) Reescribir local sin el commit raíz (ver el porqué en el encabezado):
#    rama huérfana temporal con el árbol del 2º commit como nueva raíz,
#    y rebase de los commits restantes encima.
$tmpBranch = "__tmp_nueva_raiz"
if (git branch --list $tmpBranch) { Invoke-Git branch -D $tmpBranch }
& git checkout --orphan $tmpBranch $secondHash
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo crear la rama temporal huérfana desde $secondHash."
}
& git -c commit.gpgsign=false commit --no-verify -C $secondHash
if ($LASTEXITCODE -ne 0) {
    git checkout $Branch *> $null
    if (git branch --list $tmpBranch) { git branch -D $tmpBranch *> $null }
    throw "No se pudo crear el nuevo commit raíz. La rama '$Branch' quedó como estaba."
}
$newRoot = git rev-parse HEAD
Write-Host "Nueva raíz creada: $newRoot (mismo contenido que $secondHash)."
try {
    if ($count -gt 2) {
        Write-Host "Re-aplicando los commits restantes sobre la nueva raíz..."
        & git rebase --no-gpg-sign --onto $newRoot $secondHash $Branch
        if ($LASTEXITCODE -ne 0) {
            git rebase --abort 2>$null
            throw "El rebase de los commits restantes falló y se abortó. '$Branch' quedó como estaba; la nueva raíz se conserva en '$tmpBranch' ($newRoot) por si quieres rescatarla a mano."
        }
    }
    else {
        Invoke-Git branch -f $Branch $newRoot
        Invoke-Git checkout $Branch
    }
}
finally {
    if (git branch --list $tmpBranch) { git branch -D $tmpBranch *> $null }
}

# 7) Comprobar que quedó exactamente un commit menos.
$newCount = [int](git rev-list --count HEAD)
if ($newCount -ne ($count - 1)) {
    throw "El rebase terminó pero el conteo no cuadra ($count -> $newCount). Revisa con 'git log --oneline' antes de subir nada."
}

Write-Host ""
Write-Host "Historial local resultante:"
git log --oneline -5
Write-Host ""
Write-Host "HEAD anterior (por si quieres volver atrás antes del push): $oldHead"
Write-Host "  git reset --hard $oldHead"
Write-Host ""

if ($NoPush) {
    Write-Host "Listo en local. No se hizo push (-NoPush)."
    exit 0
}

# 8) Subir el historial reescrito. Con --force-with-lease en vez de --force
#    para no pisar a nadie si el remoto cambió desde el fetch inicial.
#    (Si GitHub rechaza por protección de rama, el rebase local YA ocurrió:
#    usa el reset de arriba para volver atrás.)
Invoke-Git push --force-with-lease $Remote $Branch

Write-Host ""
Write-Host "Listo: primer commit eliminado de '$Branch' en local y en '$Remote/$Branch'."

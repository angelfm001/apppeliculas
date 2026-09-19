<#
  Funciones compartidas por los scripts de esta carpeta.
  Cárgalo al inicio de cada script con:
    . (Join-Path $PSScriptRoot "_common.ps1")
#>

# Corre un comando git y detiene el script con un mensaje claro si falla.
#
# Por qué existe: en PowerShell, cuando un PROGRAMA EXTERNO (como git.exe)
# termina con código de salida distinto de cero, eso NO cuenta como un error
# que $ErrorActionPreference = "Stop" pueda detener (esa opción solo aplica
# a cmdlets de PowerShell). Sin este wrapper, un "git pull --rebase" que
# termina en conflicto, o un "git push" rechazado, simplemente deja su
# mensaje de error en pantalla y el script sigue adelante como si nada,
# hasta terminar diciendo "Listo" aunque el repositorio haya quedado a
# medias. Esto fue justo lo que pasó y dejó un rebase atascado sin avisar.
function Invoke-Git {
    param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$GitArgs)
    & git @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw "git $($GitArgs -join ' ') falló (código de salida $LASTEXITCODE)."
    }
}

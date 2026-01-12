# Discover AL compiler (alc.exe) in VS Code extensions
function Get-HighestVersionALExtension {
    $alExtDir = Join-Path $env:USERPROFILE ".vscode\extensions"
    if (-not (Test-Path $alExtDir)) { return $null }
    $alExts = Get-ChildItem -Path $alExtDir -Filter "ms-dynamics-smb.al-*" -ErrorAction SilentlyContinue
    if (-not $alExts -or $alExts.Count -eq 0) { return $null }
    $parseVersion = {
        param($name)
        if ($name -match "ms-dynamics-smb\.al-(\d+\.\d+\.\d+)") {
            return [version]$matches[1]
        } else {
            return [version]"0.0.0"
        }
    }
    $alExtsWithVersion = $alExts | ForEach-Object {
        $ver = & $parseVersion $_.Name
        [PSCustomObject]@{ Ext = $_; Version = $ver }
    }
    $highest = $alExtsWithVersion | Sort-Object Version -Descending | Select-Object -First 1
    if ($highest) { return $highest.Ext } else { return $null }
}

function Get-ALCompilerPath {
    param([PSCustomObject]$alExtDir)
    # $alExt = Get-HighestVersionALExtension
    $alExt = $alExtDir
    if ($alExt) {
        $alc = Get-ChildItem -Path $alExt.FullName -Recurse -Filter "alc.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($alc) { return $alc.FullName }
    }
    return $null
}

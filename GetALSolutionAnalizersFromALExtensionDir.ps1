
function Get-SettingsJsonPath{
    param([string] $AppDir)

    # .vscode\settings.json
    $settingsPath = Join-Path $AppDir ".vscode\settings.json"
    return $settingsPath
}

# Discover enabled analyzer DLL paths from settings.json and AL extension
function Get-EnabledAnalyzerPaths {
    param(
        [string]$AppDir,
        [string]$AlExtPath
    )
    $settingsPath = Get-SettingsJsonPath $AppDir
    $dllMap = @{ 'CodeCop' = 'Microsoft.Dynamics.Nav.CodeCop.dll';
                 'UICop' = 'Microsoft.Dynamics.Nav.UICop.dll';
                 'AppSourceCop' = 'Microsoft.Dynamics.Nav.AppSourceCop.dll';
                 'PerTenantExtensionCop' = 'Microsoft.Dynamics.Nav.PerTenantExtensionCop.dll' }
    $supported = @('CodeCop','UICop','AppSourceCop','PerTenantExtensionCop')
    $enabled = @()

    if ($settingsPath -and (Test-Path $settingsPath)) {
        try {
            $json = Get-Content $settingsPath -Raw | ConvertFrom-Json
            if (-not $json.'al.enableCodeAnalysis') {
                return $enabled
            }
            if ($json.'al.codeAnalyzers') {
                $enabled = $json.'al.codeAnalyzers' | ForEach-Object { $_ -replace '\$\{|\}', '' }
            }
        } catch {}
    }else{
        return $enabled
    }


    # if (-not $enabled -or $enabled.Count -eq 0) {
    #     $enabled = @('CodeCop','UICop')
    # }

    # Filter and deduplicate
    $enabled = $enabled | Where-Object { $supported -contains $_ } | Select-Object -Unique
    # Find DLL paths in AL extension
    # $alExt = Get-HighestVersionALExtension
    $alExt = $AlExtPath
    $dllPaths = @()
    # Verify alExt(string) path is not empty and exists
    if ($alExt -and (Test-Path $alExt)) {
        foreach ($name in $enabled) {
            $dll = $dllMap[$name]
            if ($dll) {
                $found = Get-ChildItem -Path $alExt -Recurse -Filter $dll -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) {
                    $dllPaths += $found.FullName
                }
            }
        }
    }
    return $dllPaths
}

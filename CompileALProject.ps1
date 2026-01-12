function Test-Directory {
    param([string]$Path)
    if (-Not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Get-DefaultSymbolsPath {
    param([string]$ProjectPath, [string]$SymbolsPath)
    if (-Not $SymbolsPath) {
        # ProjectPath concat .alpackages directory
        $SymbolsPath = Join-Path $ProjectPath ".alpackages"
    }
    return $SymbolsPath
}

function Get-Analyzer {
    param([string]$ProjectPath, [string]$alExtensionPath)
    $analizerPath = Get-EnabledAnalyzerPaths -AppDir $ProjectPath -AlExtPath $alExtensionPath
    if ($analizerPath.Count -gt 0) {
        Write-Host "Enabled analyzers:"
        $analizerPath | ForEach-Object { Write-Host $_}
        return "/analyzer:`"$($analizerPath -join ',')`""
    }

    Write-Host "No analyzers enabled."
    return ""
    
}

function Get-NewVersion {
    param(
        [version]$CurrentVersion,
        [string]$VersionPart,
        [version]$CustomVersion
    )
    switch ($VersionPart) {
        "major" { return Update-Version -CurrentVersion $CurrentVersion -Major }
        "minor" { return Update-Version -CurrentVersion $CurrentVersion -Minor }
        "build" { return Update-Version -CurrentVersion $CurrentVersion -Build }
        "revision" { return Update-Version -CurrentVersion $CurrentVersion -Revision }
        "custom" {
            if ($CustomVersion) {
                return Update-Version -CurrentVersion $CurrentVersion -custom $CustomVersion
            }
            else {
                Write-Error "Custom version not provided."
                return $null
            }
        }
        default {
            Write-Error "Invalid version part specified."
            return $null
        }
    }
}

function Get-OutputAppPath {
    param($OutputPath, $solutionInfo, $CurrentVersion)
    return Join-Path $OutputPath "$($solutionInfo.Publisher)_$($solutionInfo.Name)_$($CurrentVersion.ToString())_PTE.app"
}

function Invoke-BuildALProject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,
        [Parameter(Mandatory = $false)]
        [string]$SymbolsPath,
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,
        [Parameter(Mandatory = $false)]
        [ValidateSet("major", "minor", "build", "revision", "custom")]
        [string]$VersionPart = "revision",
        [Parameter(Mandatory = $false)]
        [version]$CustomVersion
    )


    # Verify that output path is provided, if not use project path with "out" subfolder
    if (-Not $OutputPath) {
        $OutputPath = Join-Path $ProjectPath "out"
    }
    Test-Directory $OutputPath

    $SymbolsPath = Get-DefaultSymbolsPath -ProjectPath $ProjectPath -SymbolsPath $SymbolsPath

    $alExtensionPath = Get-HighestVersionALExtension
    if ($null -eq $alExtensionPath) {
        Write-Error "AL extension not found in VS Code extensions."
        return $null
    }

    $alExtensionCompilerPath = Get-ALCompilerPath -alExtDir $alExtensionPath
    Write-Host "AL Extension Path: $($alExtensionCompilerPath)"

    if ($null -eq $alExtensionCompilerPath) {
        Write-Error "AL extension not found"
        return $null
    }

    $analizerParam = Get-Analyzer -ProjectPath $ProjectPath -alExtensionPath $alExtensionPath.FullName

    $solutionInfo = Get-SolutionVersion -SolutionPath $ProjectPath
    if ($null -eq $solutionInfo) {
        Write-Error "Failed to get solution information."
        return $null
    }

    $CurrentVersion = [version]$solutionInfo.Version
    $newVersion = Get-NewVersion -CurrentVersion $CurrentVersion -VersionPart $VersionPart -CustomVersion $CustomVersion

    $outputAppPath = Get-OutputAppPath -OutputPath $OutputPath -solutionInfo $solutionInfo -CurrentVersion $CurrentVersion

    Write-Host "Parameters:"
    Write-Host "ProjectPath: $ProjectPath"
    Write-Host "SymbolsPath: $SymbolsPath"
    Write-Host "OutputPath: $OutputPath"
    Write-Host "OutputAppPath: $outputAppPath"
    Write-Host "Current Version: $CurrentVersion"
    Write-Host "New Version: $newVersion"

    & $alExtensionCompilerPath `
        /project:"$ProjectPath" `
        /packagecachepath:"$SymbolsPath" `
        /out:"$outputAppPath" `
        $analizerParam `
        /loglevel:verbose

    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        Write-Host ""; Write-Host "Build failed with errors above." -ForegroundColor Red
    }
    else {
        $versionUpdated = Update-SolutionVersion -SolutionPath $ProjectPath -NewVersion $newVersion
        if (-not $versionUpdated) {
            Write-Host ""; Write-Host "Failed to update solution version in app.json." -ForegroundColor Yellow
        }
        else {
            Write-Host ""; Write-Host "Solution version updated to $newVersion in app.json." -ForegroundColor Green
        }
        Write-Host ""; Write-Host "Build completed successfully: $outputAppPath" -ForegroundColor Green
    }
    return $null
}

function Get-SolutionVersion {
    param (
        [string]$SolutionPath
    )

    # read de app.json from the solution path, then parse the id, name, publisher and version; and return as object
    $appJsonPath = Join-Path $SolutionPath "app.json"
    if (-Not (Test-Path $appJsonPath)) {
        Write-Error "app.json not found in $SolutionPath"
        return $null
    }
    try {
        $appJson = Get-Content $appJsonPath -Raw | ConvertFrom-Json
        $solutionInfo = [PSCustomObject]@{
            Id        = $appJson.id
            Name      = $appJson.name
            Publisher = $appJson.publisher
            Version   = $appJson.version
        }
        return $solutionInfo
    }
    catch {
        Write-Error "Failed to read or parse app.json: $_"
        return $null
    }
}



# Reglas clave

# Major → Se reinician Minor, Build y Revision a 0.
# Minor → Se reinician Build y Revision a 0.
# Build → Se reinicia Revision a 0.
# Revision → Solo aumenta en 1.


function Update-Version {
    [CmdletBinding(DefaultParameterSetName = 'revision')]
    param(
        [Parameter(Mandatory = $true)]
        [version]$CurrentVersion,

        [Parameter(ParameterSetName = "major")]
        [switch]$Major,

        [Parameter(ParameterSetName = "minor")]
        [switch]$Minor,

        [Parameter(ParameterSetName = "build")]
        [switch]$Build,

        [Parameter(ParameterSetName = "revision")]
        [switch]$Revision,

        [Parameter(ParameterSetName = "custom")]
        [version]$CustomVersion
    )

    switch ($PSCmdlet.ParameterSetName) {
        'major' { return [version]::new($CurrentVersion.Major + 1, 0, 0, 0) }
        'minor' { return [version]::new($CurrentVersion.Major, $CurrentVersion.Minor + 1, 0, 0) }
        'build' { return [version]::new($CurrentVersion.Major, $CurrentVersion.Minor, $CurrentVersion.Build + 1, 0) }
        'revision' { return [version]::new($CurrentVersion.Major, $CurrentVersion.Minor, $CurrentVersion.Build, $CurrentVersion.Revision + 1) }
        'custom' { return [version]$CustomVersion }
        default { return $null }
    }
}

function Update-SolutionVersion {
    param (
        [string]$SolutionPath,
        [version]$NewVersion
    )

    $appJsonPath = Join-Path $SolutionPath "app.json"
    if (-Not (Test-Path $appJsonPath)) {
        Write-Error "app.json not found in $SolutionPath"
        return $false
    }

    try {
        $appJson = Get-Content $appJsonPath -Raw | ConvertFrom-Json
        $appJson.version = $NewVersion.ToString()
        $appJson | ConvertTo-Json | Format-Json | Set-Content -Path $appJsonPath -Encoding UTF8
        return $true
    }
    catch {
        Write-Error "Failed to update app.json: $_"
        return $false
    }
    
}


function Format-Json {
    <#
    .SYNOPSIS
        Applies proper formatting to a JSON string with the specified indentation.
 
    .DESCRIPTION
        The `Format-Json` function takes a JSON string as input and formats it with the specified level of indentation. 
        The function processes each line of the JSON string, adjusting the indentation level based on the structure of the JSON.
 
    .PARAMETER Json
        The JSON string to be formatted.
        This parameter is mandatory and accepts input from the pipeline.
 
    .PARAMETER Indentation
        Specifies the number of spaces to use for each indentation level.
        The value must be between 1 and 1024. 
        The default value is 2.
 
    .EXAMPLE
        $formattedJson = Get-Content -Path 'config.json' | Format-Json -Indentation 4
        This example reads the JSON content from a file named 'config.json', formats it with an 
        indentation level of 4 spaces, and stores the result in the `$formattedJson` variable.
 
    .EXAMPLE
        @'
        {
            "EnableSSL":  true,
            "MaxThreads":  8,
            "ConnectionStrings":  {
                                      "DefaultConnection":  "Server=SERVER_NAME;Database=DATABASE_NAME;Trusted_Connection=True;"
                                  }
        }
        '@ | Format-Json
        This example formats an inline JSON string with the default indentation level of 2 spaces.
 
    .NOTES
        This function assumes that the input string is valid JSON.
    #>
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [String]$Json,
 
        [ValidateRange(1, 1024)]
        [Int]$Indentation = 2
    )
 
    $indentationLevel = 0
    $insideString = $false
    $previousCharacterWasEscape = $false
    $stringBuilder = New-Object System.Text.StringBuilder
    $characters = $Json.ToCharArray()
 
    for ($i = 0; $i -lt $characters.Length; $i++) {
        $character = $characters[$i]
 
        if ($insideString) {
            [void]$stringBuilder.Append($character)
 
            if ($previousCharacterWasEscape) {
                $previousCharacterWasEscape = $false
            }
            elseif ($character -eq '\') {
                if ($i + 1 -lt $characters.Length) {
                    $nextCharacter = $characters[$i + 1]
 
                    # Check for valid escape sequences: \", \\, \/, \b, \f, \n, \r, \t, \uXXXX
                    if ($nextCharacter -in @('"', '\', '/', 'b', 'f', 'n', 'r', 't', 'u')) {
                        $previousCharacterWasEscape = $true
                    }
                }
            }
            elseif ($character -eq '"') {
                $insideString = $false
            }
        }
        else {
            switch ($character) {
                '"' {
                    $insideString = $true
                    [void]$stringBuilder.Append($character)
                }
                '{' {
                    [void]$stringBuilder.Append($character)
                    $indentationLevel++
                    [void]$stringBuilder.Append("`n" + (' ' * ($indentationLevel * $Indentation)))
                }
                '[' {
                    [void]$stringBuilder.Append($character)
                    $indentationLevel++
                    [void]$stringBuilder.Append("`n" + (' ' * ($indentationLevel * $Indentation)))
                }
                '}' {
                    $indentationLevel--
                    [void]$stringBuilder.Append("`n" + (' ' * ($indentationLevel * $Indentation)) + $character)
                }
                ']' {
                    $indentationLevel--
                    [void]$stringBuilder.Append("`n" + (' ' * ($indentationLevel * $Indentation)) + $character)
                }
                ',' {
                    [void]$stringBuilder.Append($character)
                    [void]$stringBuilder.Append("`n" + (' ' * ($indentationLevel * $Indentation)))
                }
                ':' {
                    [void]$stringBuilder.Append(": ")
                }
                default {
                    if (-not [char]::IsWhiteSpace($character)) {
                        [void]$stringBuilder.Append($character)
                    }
                }
            }
        }
    }
 
    return $stringBuilder.ToString()
}
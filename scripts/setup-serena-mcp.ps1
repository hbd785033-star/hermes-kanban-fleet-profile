[CmdletBinding()]
param(
    [switch]$ReplaceExisting
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Stop-Setup {
    param(
        [Parameter(Mandatory = $true)][string]$Code,
        [Parameter(Mandatory = $true)][string]$Message,
        [int]$ExitCode = 1
    )

    Write-Error ("{0}: {1}" -f $Code, $Message)
    exit $ExitCode
}

function Resolve-Application {
    param([Parameter(Mandatory = $true)][string[]]$Names)

    foreach ($name in $Names) {
        $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $command) {
            return [System.IO.Path]::GetFullPath($command.Source)
        }
    }
    return $null
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$FailureCode
    )

    $output = @(& $Executable @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        Stop-Setup -Code $FailureCode -Message ($output -join [Environment]::NewLine)
    }
    return $output
}

function Normalize-ConfigList {
    param([string[]]$Lines)

    $values = @()
    foreach ($line in $Lines) {
        $value = ($line -replace '^\s*-\s*', '').Trim()
        $value = $value.Trim("'", '"')
        if ($value.Length -gt 0) {
            $values += $value
        }
    }
    return $values
}

function Get-OptionalConfigValue {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string]$Key
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = @(& $Executable config get $Key 2>$null)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    return [PSCustomObject]@{ Output = $output; ExitCode = $exitCode }
}

$serenaPath = Resolve-Application -Names @("serena.exe", "serena")
$uvPath = Resolve-Application -Names @("uv.exe", "uv")
$uvxPath = Resolve-Application -Names @("uvx.exe", "uvx")
$serenaDistribution = $null

if ($null -ne $uvPath) {
    $uvToolList = @(& $uvPath tool list 2>$null)
    if ($LASTEXITCODE -eq 0) {
        $distributionLine = $uvToolList | Where-Object { $_ -match '^serena-agent\s+v\S+' } | Select-Object -First 1
        if ($null -ne $distributionLine) {
            $serenaDistribution = "serena-agent"
        }
    }
}

if ($null -eq $serenaPath -and $null -ne $uvPath) {
    $uvBinOutput = @(& $uvPath tool dir --bin 2>$null)
    if ($LASTEXITCODE -eq 0 -and $uvBinOutput.Count -gt 0) {
        $uvBin = ($uvBinOutput | Where-Object { $_.Trim().Length -gt 0 } | Select-Object -Last 1).Trim()
        $candidate = Join-Path $uvBin "serena.exe"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $serenaPath = [System.IO.Path]::GetFullPath($candidate)
        }
    }
}

if ($null -eq $serenaPath) {
    $userHome = [Environment]::GetFolderPath("UserProfile")
    if (-not [string]::IsNullOrWhiteSpace($userHome)) {
        $candidate = Join-Path $userHome ".local\bin\serena.exe"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $serenaPath = [System.IO.Path]::GetFullPath($candidate)
        }
    }
}

if ($null -eq $serenaPath) {
    Write-Output "SERENA_NOT_INSTALLED"
    if ($null -eq $uvPath -and $null -eq $uvxPath) {
        Write-Output "Install uv first, then install the validated distribution explicitly: uv tool install serena-agent"
    }
    else {
        Write-Output "Install the validated distribution explicitly: uv tool install serena-agent"
    }
    exit 2
}

$serenaVersion = Invoke-Checked -Executable $serenaPath -Arguments @("--version") -FailureCode "SERENA_VERSION_FAILED"
$serenaHelp = Invoke-Checked -Executable $serenaPath -Arguments @("start-mcp-server", "--help") -FailureCode "SERENA_HELP_FAILED"
$serenaHelpText = $serenaHelp -join "`n"
$requiredHelpContracts = @(
    @{ Name = "start-mcp-server"; Pattern = "Starts the Serena MCP server|start-mcp-server" },
    @{ Name = "--transport stdio"; Pattern = "(?s)--transport.*stdio" },
    @{ Name = "--project-from-cwd"; Pattern = "--project-from-cwd" },
    @{ Name = "--open-web-dashboard"; Pattern = "--open-web-dashboard" }
)
foreach ($contract in $requiredHelpContracts) {
    if ($serenaHelpText -notmatch $contract.Pattern) {
        Stop-Setup -Code "SERENA_VERSION_INCOMPATIBLE" -Message ("Installed Serena does not advertise {0}. Version output: {1}" -f $contract.Name, ($serenaVersion -join " "))
    }
}

$hermesPath = Resolve-Application -Names @("hermes.exe", "hermes")
if ($null -eq $hermesPath) {
    Stop-Setup -Code "HERMES_NOT_INSTALLED" -Message "The hermes executable was not found."
}

$hermesVersion = Invoke-Checked -Executable $hermesPath -Arguments @("--version") -FailureCode "HERMES_VERSION_FAILED"
$null = Invoke-Checked -Executable $hermesPath -Arguments @("mcp", "--help") -FailureCode "HERMES_MCP_UNAVAILABLE"
$mcpListBefore = Invoke-Checked -Executable $hermesPath -Arguments @("mcp", "list") -FailureCode "HERMES_MCP_LIST_FAILED"
$null = Invoke-Checked -Executable $hermesPath -Arguments @("mcp", "add", "--help") -FailureCode "HERMES_MCP_ADD_UNAVAILABLE"
$null = Invoke-Checked -Executable $hermesPath -Arguments @("mcp", "test", "--help") -FailureCode "HERMES_MCP_TEST_UNAVAILABLE"

$configPathOutput = Invoke-Checked -Executable $hermesPath -Arguments @("config", "path") -FailureCode "HERMES_CONFIG_PATH_FAILED"
$configPath = ($configPathOutput | Where-Object { $_.Trim().Length -gt 0 } | Select-Object -Last 1).Trim()
$configPath = [System.IO.Path]::GetFullPath($configPath)
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    Stop-Setup -Code "HERMES_CONFIG_NOT_FOUND" -Message ("Resolved config file does not exist: {0}" -f $configPath)
}

$defaultProfileOutput = Invoke-Checked -Executable $hermesPath -Arguments @("profile", "show", "default") -FailureCode "HERMES_DEFAULT_PROFILE_LOOKUP_FAILED"
$defaultPathLine = $defaultProfileOutput | Where-Object { $_ -match '^Path:\s+' } | Select-Object -First 1
if ($null -eq $defaultPathLine) {
    Stop-Setup -Code "HERMES_DEFAULT_PROFILE_UNKNOWN" -Message "Could not determine the default Profile path from current Hermes CLI output."
}
$defaultProfilePath = [System.IO.Path]::GetFullPath(($defaultPathLine -replace '^Path:\s+', '').Trim())
$configDirectory = [System.IO.Path]::GetFullPath((Split-Path -Parent $configPath))
if (-not $configDirectory.Equals($defaultProfilePath, [System.StringComparison]::OrdinalIgnoreCase)) {
    Stop-Setup -Code "NON_DEFAULT_PROFILE_ACTIVE" -Message ("Active config is {0}; default Profile config is under {1}. No changes were made." -f $configPath, $defaultProfilePath)
}

$targetArgs = @(
    "start-mcp-server",
    "--transport",
    "stdio",
    "--project-from-cwd",
    "--open-web-dashboard",
    "false"
)

$existingEntryResult = Get-OptionalConfigValue -Executable $hermesPath -Key "mcp_servers.serena"
$existingEntryOutput = @($existingEntryResult.Output)
$serenaEntryExists = ($existingEntryResult.ExitCode -eq 0 -and $existingEntryOutput.Count -gt 0)
$existingCommandResult = Get-OptionalConfigValue -Executable $hermesPath -Key "mcp_servers.serena.command"
$existingCommandOutput = @($existingCommandResult.Output)
$existingCommandPresent = ($existingCommandResult.ExitCode -eq 0 -and $existingCommandOutput.Count -gt 0)
$existingUrlResult = Get-OptionalConfigValue -Executable $hermesPath -Key "mcp_servers.serena.url"
$existingUrlOutput = @($existingUrlResult.Output)
$existingUrlPresent = ($existingUrlResult.ExitCode -eq 0 -and $existingUrlOutput.Count -gt 0)
$configurationMatches = $false

if ($existingCommandPresent) {
    $existingCommand = ($existingCommandOutput | Select-Object -Last 1).Trim()
    $resolvedExistingCommand = $null
    if (Test-Path -LiteralPath $existingCommand -PathType Leaf) {
        $resolvedExistingCommand = [System.IO.Path]::GetFullPath($existingCommand)
    }
    else {
        $resolvedExistingCommand = Resolve-Application -Names @($existingCommand)
    }

    $existingArgsOutput = @((Get-OptionalConfigValue -Executable $hermesPath -Key "mcp_servers.serena.args").Output)
    $existingArgs = Normalize-ConfigList -Lines $existingArgsOutput
    $existingTimeoutOutput = @((Get-OptionalConfigValue -Executable $hermesPath -Key "mcp_servers.serena.connect_timeout").Output)
    $existingEnabledOutput = @((Get-OptionalConfigValue -Executable $hermesPath -Key "mcp_servers.serena.enabled").Output)
    $existingTimeout = 0.0
    $timeoutParsed = $false
    if ($existingTimeoutOutput.Count -gt 0) {
        $timeoutParsed = [double]::TryParse(
            (($existingTimeoutOutput | Select-Object -Last 1).Trim()),
            [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$existingTimeout
        )
    }
    $existingEnabled = $true
    if ($existingEnabledOutput.Count -gt 0) {
        $existingEnabled = (($existingEnabledOutput | Select-Object -Last 1).Trim() -ieq "true")
    }
    $argsMatch = ($null -eq (Compare-Object -ReferenceObject $targetArgs -DifferenceObject $existingArgs -SyncWindow 0))
    $commandMatches = ($null -ne $resolvedExistingCommand -and $resolvedExistingCommand.Equals($serenaPath, [System.StringComparison]::OrdinalIgnoreCase))
    $configurationMatches = ($commandMatches -and $argsMatch -and $timeoutParsed -and $existingTimeout -eq 30.0 -and $existingEnabled -and -not $existingUrlPresent)

    if (-not $configurationMatches) {
        Write-Output "SERENA_CONFIG_CONFLICT"
        Write-Output ("Existing Serena command: {0}" -f $existingCommand)
        if (-not $ReplaceExisting) {
            Write-Output "Existing Serena configuration was preserved. Review it, then rerun with -ReplaceExisting to replace only the default Profile Serena entry."
            exit 3
        }
        Write-Output "Replacement explicitly authorized; only the default Profile Serena entry will be changed after backup."
    }
}
elseif ($serenaEntryExists) {
    Write-Output "SERENA_CONFIG_CONFLICT"
    if ($existingUrlPresent) {
        Write-Output "Existing Serena transport: HTTP"
    }
    else {
        Write-Output "Existing Serena transport could not be classified safely."
    }
    if (-not $ReplaceExisting) {
        Write-Output "Existing Serena configuration was preserved. Review it, then rerun with -ReplaceExisting to replace only the default Profile Serena entry."
        exit 3
    }
    Write-Output "Replacement explicitly authorized; only the default Profile Serena entry will be changed after backup."
}

$backupPath = $null
if (-not $configurationMatches) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
    $backupPath = "{0}.serena-backup.{1}" -f $configPath, $timestamp
    Copy-Item -LiteralPath $configPath -Destination $backupPath -ErrorAction Stop

    try {
        if ($serenaEntryExists) {
            $unsetOutput = @(& $hermesPath config unset mcp_servers.serena 2>&1)
            if ($LASTEXITCODE -ne 0) {
                throw ("Hermes could not remove the existing Serena config entry: {0}" -f ($unsetOutput -join [Environment]::NewLine))
            }
        }

        $addArguments = @(
            "mcp", "add", "serena",
            "--command", $serenaPath,
            "--connect-timeout", "30",
            "--args"
        ) + $targetArgs
        $addOutput = @(Write-Output "y" | & $hermesPath @addArguments 2>&1)
        if ($LASTEXITCODE -ne 0 -or (($addOutput -join "`n") -notmatch "Saved 'serena'")) {
            throw ("Hermes MCP add did not confirm a saved Serena configuration: {0}" -f ($addOutput -join [Environment]::NewLine))
        }
    }
    catch {
        Copy-Item -LiteralPath $backupPath -Destination $configPath -Force
        Stop-Setup -Code "SERENA_CONFIG_APPLY_FAILED" -Message ("{0} Original config restored from {1}." -f $_.Exception.Message, $backupPath)
    }
}

$probeDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("hermes-serena-mcp-probe-{0}" -f [Guid]::NewGuid().ToString("N"))
$null = New-Item -ItemType Directory -Path $probeDirectory
$mcpTest = @()
try {
    Push-Location $probeDirectory
    try {
        $mcpTest = @(& $hermesPath mcp test serena 2>&1)
        $mcpTestExitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
}
finally {
    Remove-Item -LiteralPath $probeDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
$mcpTestText = $mcpTest -join "`n"
if ($mcpTestExitCode -ne 0 -or $mcpTestText -notmatch "Connected" -or $mcpTestText -notmatch "Tools discovered:\s*[1-9][0-9]*") {
    if ($null -ne $backupPath) {
        Copy-Item -LiteralPath $backupPath -Destination $configPath -Force
        Stop-Setup -Code "SERENA_MCP_TEST_FAILED" -Message ("{0} Original config restored from {1}." -f $mcpTestText, $backupPath)
    }
    Stop-Setup -Code "SERENA_MCP_TEST_FAILED" -Message $mcpTestText
}

Write-Output ("Hermes: {0}" -f (($hermesVersion | Select-Object -First 1).Trim()))
Write-Output ("Serena: {0}" -f (($serenaVersion | Select-Object -First 1).Trim()))
if ($null -ne $serenaDistribution) {
    Write-Output ("Serena distribution: {0} (verified by uv tool list)" -f $serenaDistribution)
}
Write-Output ("Serena executable: {0}" -f $serenaPath)
Write-Output ("Default Profile config: {0}" -f $configPath)
if ($configurationMatches) {
    Write-Output "ALREADY_CONFIGURED"
    Write-Output "Configuration: already correct; no change required"
}
else {
    Write-Output ("Configuration: updated; backup created at {0}" -f $backupPath)
}
Write-Output "Transport: stdio"
Write-Output "MCP verification: PASS"
Write-Output ($mcpTestText.Trim())

<#
.SYNOPSIS
    Phase 2: Nutanix v4 API Environment Setup

.DESCRIPTION
    This script handles the complete Phase 2 workflow:
    1. Downloads the Install-NtnxV4ApiEnvironment.ps1 script from ntnx-v4api-cats repository
    2. Configures the environment setup parameters
    3. Executes the API environment installation
    4. Validates the installation and creates usage documentation

.PARAMETER ConfigPath
    Path to the environment configuration file

.PARAMETER LogPath
    Path to write execution logs

.PARAMETER WorkingDirectory
    Directory for temporary files and installations

.PARAMETER InstallPath
    Target installation path for the API environment

.EXAMPLE
    .\Initialize-APIEnvironment.ps1 -ConfigPath "config\environment-config.json"

.NOTES
    Author: Hardev Sanghera
    Date: October 2025
    Requires: PowerShell 7+, Internet connectivity, Administrative privileges (recommended)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "config\environment-config.json",
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "logs\phase2.log",
    
    [Parameter(Mandatory = $false)]
    [string]$WorkingDirectory = "temp",
    
    [Parameter(Mandatory = $false)]
    [string]$InstallPath = ""
)

# Import required modules
. "$PSScriptRoot\Install-NtnxEnvironment.ps1"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$LogFile = $LogPath
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to console
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARN" { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        default { Write-Host $logEntry -ForegroundColor White }
    }
    
    # Write to log file
    try {
        $logDir = Split-Path $LogFile -Parent
        if (!(Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        Add-Content -Path $LogFile -Value $logEntry
    }
    catch {
        Write-Warning "Failed to write to log file: $($_.Exception.Message)"
    }
}

function Test-Phase2Prerequisites {
    Write-Log "Checking Phase 2 prerequisites..."
    
    $issues = @()
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $issues += "PowerShell 7+ is required for optimal performance. Current version: $($PSVersionTable.PSVersion)"
    }
    else {
        Write-Log "PowerShell version check passed: $($PSVersionTable.PSVersion)" -Level "SUCCESS"
    }
    
    # Check internet connectivity
    try {
        Test-Connection -ComputerName "github.com" -Count 1 -ErrorAction Stop | Out-Null
        Write-Log "Internet connectivity verified" -Level "SUCCESS"
    }
    catch {
        $issues += "Internet connectivity check failed: $($_.Exception.Message)"
    }
    
    # Check if running as administrator (recommended)
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($isAdmin) {
        Write-Log "Running with administrative privileges" -Level "SUCCESS"
    }
    else {
        Write-Log "Not running as administrator. Some installations may require manual intervention." -Level "WARN"
    }
    
    # Check available disk space (at least 5GB recommended)
    $systemDrive = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $env:SystemDrive }
    $freeSpaceGB = [math]::Round($systemDrive.FreeSpace / 1GB, 2)
    
    if ($freeSpaceGB -lt 5) {
        $issues += "Low disk space: ${freeSpaceGB}GB available. At least 5GB recommended."
    }
    else {
        Write-Log "Disk space check passed: ${freeSpaceGB}GB available" -Level "SUCCESS"
    }
    
    if ($issues.Count -gt 0) {
        Write-Log "Prerequisites issues found:" -Level "WARN"
        foreach ($issue in $issues) {
            Write-Log "  - $issue" -Level "WARN"
        }
        
        $continue = Read-Host "Continue with installation? (y/N)"
        if ($continue -notmatch "^[Yy]") {
            return $false
        }
    }
    
    return $true
}

function Get-InstallationScript {
    param([string]$WorkingDir)
    
    Write-Log "Downloading Nutanix v4 API environment installation script..."
    
    $scriptUrl = "https://raw.githubusercontent.com/hardevsanghera/ntnx-v4api-cats/main/experimental/Install-NtnxV4ApiEnvironment.ps1"
    $scriptPath = Join-Path $WorkingDir "Install-NtnxV4ApiEnvironment.ps1"
    
    try {
        # Create working directory if it doesn't exist
        if (!(Test-Path $WorkingDir)) {
            New-Item -Path $WorkingDir -ItemType Directory -Force | Out-Null
        }
        
        Write-Log "Downloading from: $scriptUrl"
        Write-Log "Saving to: $scriptPath"
        
        Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing
        
        if (Test-Path $scriptPath) {
            $fileSize = (Get-Item $scriptPath).Length
            Write-Log "Installation script downloaded successfully ($fileSize bytes)" -Level "SUCCESS"
            return $scriptPath
        }
        else {
            throw "Downloaded file not found at expected location"
        }
    }
    catch {
        Write-Log "Failed to download installation script: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Read-EnvironmentConfig {
    param([string]$ConfigFile)
    
    Write-Log "Reading environment configuration from: $ConfigFile"
    
    try {
        if (!(Test-Path $ConfigFile)) {
            Write-Log "Configuration file not found: $ConfigFile" -Level "ERROR"
            return $null
        }
        
        $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        Write-Log "Environment configuration loaded successfully" -Level "SUCCESS"
        return $config
    }
    catch {
        Write-Log "Failed to read configuration: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Build-InstallationParameters {
    param([object]$Config)
    
    Write-Log "Building installation parameters from configuration..."
    
    $parameters = @{}
    
    # Set repository path
    if ($Config.environment.installPath) {
        $parameters['RepositoryPath'] = $Config.environment.installPath
        Write-Log "Install path: $($Config.environment.installPath)"
    }
    
    # Set skip git clone if specified
    if ($Config.environment.skipGitClone) {
        $parameters['SkipGitClone'] = $true
        Write-Log "Git clone will be skipped"
    }
    
    # Set force reinstall if specified
    if ($Config.environment.forceReinstall) {
        $parameters['Force'] = $true
        Write-Log "Force reinstall enabled"
    }
    
    Write-Log "Installation parameters built successfully" -Level "SUCCESS"
    return $parameters
}

function Start-Phase2Installation {
    param(
        [string]$ScriptPath,
        [hashtable]$Parameters
    )
    
    Write-Log "=== STARTING PHASE 2: API ENVIRONMENT SETUP ===" -Level "SUCCESS"
    
    try {
        Write-Log "Executing Nutanix v4 API environment installation..."
        Write-Log "Script: $ScriptPath"
        
        # Prepare parameter string
        $paramString = ""
        foreach ($key in $Parameters.Keys) {
            if ($Parameters[$key] -is [bool] -and $Parameters[$key]) {
                $paramString += " -$key"
            }
            elseif ($Parameters[$key] -is [string] -and $Parameters[$key]) {
                $paramString += " -$key `"$($Parameters[$key])`""
            }
        }
        
        Write-Log "Parameters: $paramString"
        
        # Execute the installation script
        $scriptBlock = [ScriptBlock]::Create("& `"$ScriptPath`" $paramString")
        $result = Invoke-Command -ScriptBlock $scriptBlock
        
        Write-Log "Installation script execution completed" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Installation failed: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Validate-Installation {
    param([object]$Config)
    
    Write-Log "Validating Phase 2 installation..."
    
    $validationResults = @{
        PowerShell7 = $false
        Python = $false
        VSCode = $false
        Git = $false
        Repository = $false
        OverallSuccess = $false
    }
    
    # Check PowerShell 7
    if ($Config.components.powershell7.install) {
        try {
            $pwshVersion = pwsh --version 2>&1
            if ($pwshVersion -match "PowerShell (\d+\.\d+)") {
                $version = [version]$matches[1]
                if ($version.Major -ge 7) {
                    $validationResults.PowerShell7 = $true
                    Write-Log "PowerShell 7 validation passed: $pwshVersion" -Level "SUCCESS"
                }
            }
        }
        catch {
            Write-Log "PowerShell 7 validation failed" -Level "WARN"
        }
    }
    else {
        $validationResults.PowerShell7 = $true # Not required
    }
    
    # Check Python
    if ($Config.components.python.install) {
        try {
            $pythonVersion = python --version 2>&1
            if ($pythonVersion -match "Python (\d+\.\d+)") {
                $version = [version]$matches[1]
                if ($version.Major -eq 3 -and $version.Minor -ge 13) {
                    $validationResults.Python = $true
                    Write-Log "Python validation passed: $pythonVersion" -Level "SUCCESS"
                }
            }
        }
        catch {
            Write-Log "Python validation failed" -Level "WARN"
        }
    }
    else {
        $validationResults.Python = $true # Not required
    }
    
    # Check VS Code
    if ($Config.components.vscode.install) {
        try {
            code --version | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $validationResults.VSCode = $true
                Write-Log "VS Code validation passed" -Level "SUCCESS"
            }
        }
        catch {
            Write-Log "VS Code validation failed" -Level "WARN"
        }
    }
    else {
        $validationResults.VSCode = $true # Not required
    }
    
    # Check Git
    if ($Config.components.git.install) {
        try {
            git --version | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $validationResults.Git = $true
                Write-Log "Git validation passed" -Level "SUCCESS"
            }
        }
        catch {
            Write-Log "Git validation failed" -Level "WARN"
        }
    }
    else {
        $validationResults.Git = $true # Not required
    }
    
    # Check Repository
    $repoPath = $Config.environment.installPath
    if ($repoPath -and (Test-Path $repoPath)) {
        # Check for key files
        $keyFiles = @("list_vms.ps1", "list_categories.ps1", "build_workbook.ps1")
        $filesFound = 0
        
        foreach ($file in $keyFiles) {
            if (Test-Path (Join-Path $repoPath $file)) {
                $filesFound++
            }
        }
        
        if ($filesFound -eq $keyFiles.Count) {
            $validationResults.Repository = $true
            Write-Log "Repository validation passed" -Level "SUCCESS"
        }
        else {
            Write-Log "Repository validation failed: $filesFound/$($keyFiles.Count) key files found" -Level "WARN"
        }
    }
    else {
        Write-Log "Repository path not found or not configured" -Level "WARN"
    }
    
    # Overall success
    $validationResults.OverallSuccess = $validationResults.PowerShell7 -and 
                                       $validationResults.Python -and 
                                       $validationResults.VSCode -and 
                                       $validationResults.Git -and 
                                       $validationResults.Repository
    
    return $validationResults
}

function Generate-Phase2Summary {
    param(
        [object]$Config,
        [object]$ValidationResults
    )
    
    Write-Log "Generating Phase 2 installation summary..."
    
    $summary = @"
=== PHASE 2 INSTALLATION SUMMARY ===
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Installation Path: $($Config.environment.installPath)

Component Status:
- PowerShell 7: $(if ($ValidationResults.PowerShell7) { "✓ PASS" } else { "✗ FAIL" })
- Python 3.13+: $(if ($ValidationResults.Python) { "✓ PASS" } else { "✗ FAIL" })
- Visual Studio Code: $(if ($ValidationResults.VSCode) { "✓ PASS" } else { "✗ FAIL" })
- Git for Windows: $(if ($ValidationResults.Git) { "✓ PASS" } else { "✗ FAIL" })
- API Repository: $(if ($ValidationResults.Repository) { "✓ PASS" } else { "✗ FAIL" })

Overall Status: $(if ($ValidationResults.OverallSuccess) { "SUCCESS" } else { "INCOMPLETE" })

Next Steps:
1. Configure files\vars.txt with your Nutanix Prism Central details
2. Run the API workflow scripts in order:
   - .\list_vms.ps1
   - .\list_categories.ps1
   - .\build_workbook.ps1
3. Use VS Code for development and testing

Documentation:
- Repository: https://github.com/hardevsanghera/ntnx-v4api-cats
- README.md contains detailed usage instructions
"@

    Write-Log $summary -Level "SUCCESS"
    
    # Save summary to file
    try {
        $summaryPath = Join-Path $WorkingDirectory "phase2-summary.txt"
        $summary | Set-Content $summaryPath
        Write-Log "Summary saved to: $summaryPath" -Level "SUCCESS"
    }
    catch {
        Write-Log "Failed to save summary file: $($_.Exception.Message)" -Level "WARN"
    }
    
    return $summary
}

# Main execution
try {
    Write-Log "=== PHASE 2 INITIALIZATION ===" -Level "SUCCESS"
    
    # Check prerequisites
    if (!(Test-Phase2Prerequisites)) {
        throw "Prerequisites check failed"
    }
    
    # Read configuration
    $config = Read-EnvironmentConfig -ConfigFile $ConfigPath
    if (!$config) {
        throw "Failed to load environment configuration"
    }
    
    # Override install path if specified in parameters
    if ($InstallPath) {
        $config.environment.installPath = $InstallPath
    }
    
    # Download installation script
    $scriptPath = Get-InstallationScript -WorkingDir $WorkingDirectory
    if (!$scriptPath) {
        throw "Failed to download installation script"
    }
    
    # Build installation parameters
    $parameters = Build-InstallationParameters -Config $config
    
    # Execute installation
    Write-Log "Starting Phase 2 installation process..."
    $installSuccess = Start-Phase2Installation -ScriptPath $scriptPath -Parameters $parameters
    
    if ($installSuccess) {
        Write-Log "Phase 2 installation completed" -Level "SUCCESS"
        
        # Validate installation
        $validationResults = Validate-Installation -Config $config
        
        # Generate summary
        $summary = Generate-Phase2Summary -Config $config -ValidationResults $validationResults
        
        if ($validationResults.OverallSuccess) {
            Write-Log "Phase 2 completed successfully! Environment is ready for use." -Level "SUCCESS"
        }
        else {
            Write-Log "Phase 2 completed with some issues. Check validation results." -Level "WARN"
        }
        
        return @{
            Success = $installSuccess
            ValidationResults = $validationResults
            Summary = $summary
        }
    }
    else {
        throw "Phase 2 installation failed"
    }
}
catch {
    Write-Log "Phase 2 failed: $($_.Exception.Message)" -Level "ERROR"
    throw
}
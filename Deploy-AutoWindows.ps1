<#
.SYNOPSIS
    Auto-Windows: Master Orchestration Script for Two-Phase Deployment

.DESCRIPTION
    Coordinates the complete two-phase Windows VM deployment and API environment setup:
    
    PHASE 1: Windows VM Deployment
    - Clones deploy_win_vm_v1 repository
    - Sets up Python environment for VM deployment
    - Executes VM deployment workflow (resource selection + deployment)
    
    PHASE 2: Nutanix v4 API Environment Setup  
    - Downloads Install-NtnxV4ApiEnvironment.ps1 script
    - Installs PowerShell 7, Python 3.13+, VS Code, Git
    - Sets up Nutanix v4 API development environment

.PARAMETER Phase
    Specify which phase to run: "1", "2", or "All" (default: All)

.PARAMETER ConfigDirectory
    Directory containing configuration files (default: config)

.PARAMETER WorkingDirectory
    Directory for temporary files and operations (default: temp)

.PARAMETER LogDirectory
    Directory for execution logs (default: logs)

.PARAMETER SkipPrerequisites
    Skip prerequisite checks and continue with execution

.PARAMETER NonInteractive
    Run in non-interactive mode (use configuration defaults)

.PARAMETER DelPw
    Delete cached passwords and exit (use when you need to change credentials)

.EXAMPLE
    .\Deploy-AutoWindows.ps1
    
    Run complete two-phase deployment with interactive prompts

.EXAMPLE
    .\Deploy-AutoWindows.ps1 -Phase 1 -NonInteractive
    
    Run only Phase 1 in non-interactive mode

.EXAMPLE
    .\Deploy-AutoWindows.ps1 -Phase 2 -ConfigDirectory "custom-config"
    
    Run only Phase 2 with custom configuration directory

.EXAMPLE
    .\Deploy-AutoWindows.ps1 -DelPw
    
    Delete cached passwords for admin users

.NOTES
    Author: Hardev Sanghera
    Date: October 2025
    Version: 1.0
    
    Prerequisites:
    - PowerShell 7+ (recommended)
    - Internet connectivity
    - Nutanix Prism Central access (for Phase 1)
    - Administrative privileges (recommended for Phase 2)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("1", "2", "All")]
    [string]$Phase = "All",
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigDirectory = "config",
    
    [Parameter(Mandatory = $false)]
    [string]$WorkingDirectory = "temp",
    
    [Parameter(Mandatory = $false)]
    [string]$LogDirectory = "logs",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipPrerequisites,
    
    [Parameter(Mandatory = $false)]
    [switch]$NonInteractive,
    
    [Parameter(Mandatory = $false)]
    [switch]$DelPw
)

# Set error handling
$ErrorActionPreference = 'Stop'

# Global variables
$Script:StartTime = Get-Date
$Script:LogFile = Join-Path $LogDirectory "deploy-auto-windows.log"
$Script:ExecutionResults = @{
    Phase1 = @{ Executed = $false; Success = $false; Results = $null }
    Phase2 = @{ Executed = $false; Success = $false; Results = $null }
    Overall = @{ Success = $false; Duration = $null; Summary = "" }
}

# Import password management functions
. (Join-Path $PSScriptRoot "PasswordManager.ps1")

# Handle password deletion if requested
if ($DelPw) {
    Write-Host ""
    Write-Host "🗑️  Password Deletion Requested" -ForegroundColor Yellow
    Write-Host "================================" -ForegroundColor Yellow
    
    if (Remove-CachedPassword) {
        Write-Host ""
        Write-Host "✓ Password cache cleared successfully. You will be prompted for password on next run." -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "❌ Failed to clear password cache." -ForegroundColor Red
    }
    
    Write-Host ""
    exit 0
}

#region Logging Functions

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Component = "MAIN"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] [$Component] $Message"
    
    # Write to console with colors
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARN" { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        "INFO" { Write-Host $logEntry -ForegroundColor White }
        "DEBUG" { Write-Host $logEntry -ForegroundColor Gray }
        default { Write-Host $logEntry -ForegroundColor Cyan }
    }
    
    # Write to log file
    try {
        $logDir = Split-Path $Script:LogFile -Parent
        if (!(Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        Add-Content -Path $Script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
    }
    catch {
        # Fail silently if logging fails
    }
}

function Write-Banner {
    param([string]$Title, [string]$Color = "Cyan")
    
    $border = "=" * ($Title.Length + 6)
    Write-Host ""
    Write-Host $border -ForegroundColor $Color
    Write-Host "   $Title   " -ForegroundColor $Color
    Write-Host $border -ForegroundColor $Color
    Write-Host ""
}

#endregion

#region Configuration Functions

function Initialize-Environment {
    Write-Log "Initializing Auto-Windows environment..." -Level "INFO"
    
    # Create required directories
    $directories = @($ConfigDirectory, $WorkingDirectory, $LogDirectory)
    foreach ($dir in $directories) {
        if (!(Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            Write-Log "Created directory: $dir" -Level "SUCCESS"
        }
    }
    
    # Set script location for module imports
    $Script:ScriptRoot = $PSScriptRoot
    
    Write-Log "Environment initialization completed" -Level "SUCCESS"
}

function Test-Prerequisites {
    if ($SkipPrerequisites) {
        Write-Log "Skipping prerequisite checks as requested" -Level "WARN"
        return $true
    }
    
    Write-Log "Checking system prerequisites..." -Level "INFO"
    
    $issues = @()
    
    # PowerShell version check
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $issues += "PowerShell 5.1+ is required. Current version: $($PSVersionTable.PSVersion)"
    }
    elseif ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Log "PowerShell 7+ is recommended for best experience. Current: $($PSVersionTable.PSVersion)" -Level "WARN"
    }
    else {
        Write-Log "PowerShell version check passed: $($PSVersionTable.PSVersion)" -Level "SUCCESS"
    }
    
    # Operating System check
    if ($PSVersionTable.PSEdition -eq "Core" -and $PSVersionTable.Platform -ne "Win32NT") {
        $issues += "This script is designed for Windows only"
    }
    else {
        Write-Log "Operating system check passed: Windows" -Level "SUCCESS"
    }
    
    # Internet connectivity check
    try {
        Test-Connection -ComputerName "github.com" -Count 1 -ErrorAction Stop | Out-Null
        Write-Log "Internet connectivity verified" -Level "SUCCESS"
    }
    catch {
        $issues += "Internet connectivity required but not available"
    }
    
    # Disk space check (minimum 5GB)
    try {
        $systemDrive = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $env:SystemDrive }
        $freeSpaceGB = [math]::Round($systemDrive.FreeSpace / 1GB, 2)
        
        if ($freeSpaceGB -lt 5) {
            $issues += "Insufficient disk space: ${freeSpaceGB}GB available. At least 5GB required."
        }
        else {
            Write-Log "Disk space check passed: ${freeSpaceGB}GB available" -Level "SUCCESS"
        }
    }
    catch {
        Write-Log "Could not verify disk space: $($_.Exception.Message)" -Level "WARN"
    }
    
    # Report issues
    if ($issues.Count -gt 0) {
        Write-Log "Prerequisites check failed:" -Level "ERROR"
        foreach ($issue in $issues) {
            Write-Log "  - $issue" -Level "ERROR"
        }
        
        if (!$NonInteractive) {
            $continue = Read-Host "Continue despite prerequisite issues? (y/N)"
            return ($continue -match "^[Yy]")
        }
        return $false
    }
    
    Write-Log "All prerequisites checks passed" -Level "SUCCESS"
    return $true
}

function Read-GlobalSettings {
    $settingsPath = Join-Path $ConfigDirectory "settings.json"
    
    if (!(Test-Path $settingsPath)) {
        Write-Log "Global settings file not found: $settingsPath" -Level "WARN"
        return @{
            execution = @{ phase1 = @{ enabled = $true }; phase2 = @{ enabled = $true } }
        }
    }
    
    try {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        Write-Log "Global settings loaded from: $settingsPath" -Level "SUCCESS"
        return $settings
    }
    catch {
        Write-Log "Failed to read settings: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

#endregion

#region Phase Execution Functions

function Invoke-Phase1 {
    Write-Banner "PHASE 1: Windows VM Deployment" "Green"
    
    try {
        $Script:ExecutionResults.Phase1.Executed = $true
        
        # Import Phase 1 module
        $phase1Script = Join-Path $Script:ScriptRoot "phase1\Initialize-VMDeployment.ps1"
        if (!(Test-Path $phase1Script)) {
            throw "Phase 1 script not found: $phase1Script"
        }
        
        # Prepare Phase 1 parameters
        $phase1Params = @{
            ConfigPath = Join-Path $ConfigDirectory "deployment-config.json"
            LogPath = Join-Path $LogDirectory "phase1.log"  
            WorkingDirectory = (Resolve-Path $WorkingDirectory).Path
        }
        
        Write-Log "Starting Phase 1 execution with parameters:" -Level "INFO"
        foreach ($key in $phase1Params.Keys) {
            Write-Log "  $key = $($phase1Params[$key])" -Level "DEBUG"
        }
        
        # Execute Phase 1
        Write-Log "Executing Phase 1 script..." -Level "INFO"
        $result = & $phase1Script @phase1Params
        
        if ($result -and $result.Success) {
            $Script:ExecutionResults.Phase1.Success = $true
            $Script:ExecutionResults.Phase1.Results = $result
            Write-Log "Phase 1 completed successfully!" -Level "SUCCESS"
            Write-Log "VM UUID: $($result.VMUUID)" -Level "SUCCESS"
            return $result
        }
        else {
            throw "Phase 1 execution failed or returned invalid results"
        }
    }
    catch {
        $Script:ExecutionResults.Phase1.Success = $false
        Write-Log "Phase 1 failed: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Invoke-Phase2 {
    param([object]$Phase1Results = $null)
    
    Write-Banner "PHASE 2: Nutanix v4 API Environment Setup" "Blue"
    
    try {
        $Script:ExecutionResults.Phase2.Executed = $true
        
        # Import Phase 2 module
        $phase2Script = Join-Path $Script:ScriptRoot "phase2\Initialize-APIEnvironment.ps1"
        if (!(Test-Path $phase2Script)) {
            throw "Phase 2 script not found: $phase2Script"
        }
        
        # Prepare Phase 2 parameters
        $phase2Params = @{
            ConfigPath = Join-Path $ConfigDirectory "environment-config.json"
            LogPath = Join-Path $LogDirectory "phase2.log"
            WorkingDirectory = (Resolve-Path $WorkingDirectory).Path
        }
        
        Write-Log "Starting Phase 2 execution with parameters:" -Level "INFO"
        foreach ($key in $phase2Params.Keys) {
            Write-Log "  $key = $($phase2Params[$key])" -Level "DEBUG"
        }
        
        # Execute Phase 2
        Write-Log "Executing Phase 2 script..." -Level "INFO"
        $result = & $phase2Script @phase2Params
        
        if ($result -and $result.Success) {
            $Script:ExecutionResults.Phase2.Success = $true
            $Script:ExecutionResults.Phase2.Results = $result
            Write-Log "Phase 2 completed successfully!" -Level "SUCCESS"
            return $result
        }
        else {
            throw "Phase 2 execution failed or returned invalid results"
        }
    }
    catch {
        $Script:ExecutionResults.Phase2.Success = $false
        Write-Log "Phase 2 failed: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

#endregion

#region Summary and Reporting

function Generate-ExecutionSummary {
    $endTime = Get-Date
    $duration = $endTime - $Script:StartTime
    
    Write-Banner "EXECUTION SUMMARY" "Cyan"
    
    $summary = @"
Auto-Windows Deployment Summary
==============================
Start Time: $($Script:StartTime.ToString('yyyy-MM-dd HH:mm:ss'))
End Time: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))
Duration: $($duration.ToString('hh\:mm\:ss'))

Phase Results:
"@
    
    # Phase 1 Summary
    if ($Script:ExecutionResults.Phase1.Executed) {
        $phase1Status = if ($Script:ExecutionResults.Phase1.Success) { "SUCCESS ✓" } else { "FAILED ✗" }
        $summary += "`nPhase 1 (VM Deployment): $phase1Status"
        
        if ($Script:ExecutionResults.Phase1.Success -and $Script:ExecutionResults.Phase1.Results) {
            $result = $Script:ExecutionResults.Phase1.Results
            if ($result.VMName) { $summary += "`n  VM Name: $($result.VMName)" }
            if ($result.VMUUID) { $summary += "`n  VM UUID: $($result.VMUUID)" }
            if ($result.TaskUUID) { $summary += "`n  Task UUID: $($result.TaskUUID)" }
        }
    }
    else {
        $summary += "`nPhase 1 (VM Deployment): SKIPPED"
    }
    
    # Phase 2 Summary  
    if ($Script:ExecutionResults.Phase2.Executed) {
        $phase2Status = if ($Script:ExecutionResults.Phase2.Success) { "SUCCESS ✓" } else { "FAILED ✗" }
        $summary += "`nPhase 2 (API Environment): $phase2Status"
        
        if ($Script:ExecutionResults.Phase2.Success -and $Script:ExecutionResults.Phase2.Results) {
            $result = $Script:ExecutionResults.Phase2.Results
            if ($result.ValidationResults) {
                $validation = $result.ValidationResults
                $summary += "`n  PowerShell 7: $(if ($validation.PowerShell7) { '✓' } else { '✗' })"
                $summary += "`n  Python 3.13+: $(if ($validation.Python) { '✓' } else { '✗' })"
                $summary += "`n  VS Code: $(if ($validation.VSCode) { '✓' } else { '✗' })"
                $summary += "`n  Git: $(if ($validation.Git) { '✓' } else { '✗' })"
                $summary += "`n  Repository: $(if ($validation.Repository) { '✓' } else { '✗' })"
            }
        }
    }
    else {
        $summary += "`nPhase 2 (API Environment): SKIPPED"
    }
    
    # Overall Status
    $overallSuccess = (!$Script:ExecutionResults.Phase1.Executed -or $Script:ExecutionResults.Phase1.Success) -and
                     (!$Script:ExecutionResults.Phase2.Executed -or $Script:ExecutionResults.Phase2.Success)
    
    $overallStatus = if ($overallSuccess) { "SUCCESS ✓" } else { "FAILED ✗" }
    $summary += "`n`nOverall Status: $overallStatus"
    
    # Next Steps
    if ($overallSuccess) {
        $summary += @"

Next Steps:
1. Configure Nutanix Prism Central details in the API environment
2. Use VS Code to develop and test API scripts
3. Follow the documentation for detailed usage instructions

Documentation: https://github.com/hardevsanghera/ntnx-v4api-cats
"@
    }
    else {
        $summary += @"

Troubleshooting:
1. Check the detailed logs in the '$LogDirectory' directory
2. Review prerequisite requirements
3. Ensure all configuration files are properly set
4. Run individual phases to isolate issues
"@
    }
    
    # Save summary
    $Script:ExecutionResults.Overall.Success = $overallSuccess
    $Script:ExecutionResults.Overall.Duration = $duration
    $Script:ExecutionResults.Overall.Summary = $summary
    
    Write-Log $summary -Level "INFO" -Component "SUMMARY"
    
    # Save to file
    try {
        $summaryPath = Join-Path $LogDirectory "execution-summary.txt"
        $summary | Set-Content $summaryPath
        Write-Log "Execution summary saved to: $summaryPath" -Level "SUCCESS"
    }
    catch {
        Write-Log "Failed to save summary file: $($_.Exception.Message)" -Level "WARN"
    }
    
    return $summary
}

#endregion

#region Main Execution

function Start-AutoWindowsDeployment {
    try {
        Write-Banner "AUTO-WINDOWS DEPLOYMENT" "Magenta"
        Write-Log "Starting Auto-Windows deployment process..." -Level "INFO"
        Write-Log "Phase selection: $Phase" -Level "INFO"
        Write-Log "Script root: $Script:ScriptRoot" -Level "DEBUG"
        
        # Initialize environment
        Initialize-Environment
        
        # Check prerequisites
        if (!(Test-Prerequisites)) {
            throw "Prerequisites check failed"
        }
        
        # Read global settings
        $settings = Read-GlobalSettings
        
        # Determine phases to execute
        $executePhase1 = ($Phase -eq "All" -or $Phase -eq "1") -and $settings.execution.phase1.enabled
        $executePhase2 = ($Phase -eq "All" -or $Phase -eq "2") -and $settings.execution.phase2.enabled
        
        Write-Log "Execution plan: Phase1=$executePhase1, Phase2=$executePhase2" -Level "INFO"
        
        # Confirmation prompt in interactive mode
        if (!$NonInteractive) {
            Write-Host ""
            Write-Host "Execution Plan:" -ForegroundColor Yellow
            if ($executePhase1) { Write-Host "  ✓ Phase 1: Windows VM Deployment" -ForegroundColor Green }
            if ($executePhase2) { Write-Host "  ✓ Phase 2: Nutanix v4 API Environment Setup" -ForegroundColor Green }
            Write-Host ""
            
            $confirm = Read-Host "Proceed with Auto-Windows deployment? (Y/n)"
            if ($confirm -match "^[Nn]") {
                Write-Log "Deployment cancelled by user" -Level "WARN"
                return
            }
        }
        
        # Execute phases
        $phase1Results = $null
        
        if ($executePhase1) {
            $phase1Results = Invoke-Phase1
            
            if (!$Script:ExecutionResults.Phase1.Success) {
                if ($executePhase2) {
                    Write-Log "Phase 1 failed, but Phase 2 can run independently" -Level "WARN"
                    if (!$NonInteractive) {
                        $continue = Read-Host "Continue with Phase 2? (Y/n)"
                        if ($continue -match "^[Nn]") {
                            throw "Deployment stopped after Phase 1 failure"
                        }
                    }
                }
            }
        }
        
        if ($executePhase2) {
            Invoke-Phase2 -Phase1Results $phase1Results
        }
        
        # Generate summary
        $summary = Generate-ExecutionSummary
        
        if ($Script:ExecutionResults.Overall.Success) {
            Write-Log "Auto-Windows deployment completed successfully!" -Level "SUCCESS"
        }
        else {
            Write-Log "Auto-Windows deployment completed with errors. Check logs for details." -Level "WARN"
        }
    }
    catch {
        Write-Log "Auto-Windows deployment failed: $($_.Exception.Message)" -Level "ERROR"
        Generate-ExecutionSummary
        throw
    }
}

#endregion

# Script entry point
try {
    Start-AutoWindowsDeployment
}
catch {
    Write-Log "Fatal error in Auto-Windows deployment: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
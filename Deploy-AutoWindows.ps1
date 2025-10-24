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
    - Downloads Instal                # Wait for job completion with timeout
                $jobResult = Wait-Job $ipDiscoveryJob -Timeout 180
                
                if ($jobResult) {
                    $ipResult = Receive-Job $ipDiscoveryJob
                    Remove-Job $ipDiscoveryJob
                } else {
                    Write-Log "IP discovery timed out after 180 seconds" -Level "WARN"ApiEnvironment.ps1 script
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

.PARAMETER CachePasswords
    Pre-cache all required passwords for automated deployment and exit

.EXAMPLE
    .\Deploy-AutoWindows.ps1
    
    Run complete two-phase deployment with interactive prompts

.EXAMPLE
    .\Deploy-AutoWindows.ps1 -CachePasswords
    
    Pre-cache passwords for maximum automation, then exit

.EXAMPLE
    .\Deploy-AutoWindows.ps1 -NonInteractive
    
    Run deployment with minimal prompts using cached passwords

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
    [switch]$DelPw,
    
    [Parameter(Mandatory = $false)]
    [switch]$CachePasswords
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

# Handle password pre-caching if requested
if ($CachePasswords) {
    Write-Host ""
    Write-Host "🔐 Password Pre-Caching Setup" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This will cache passwords for maximum automation during deployment." -ForegroundColor Yellow
    Write-Host "You will only need to enter passwords once, and they will be securely cached." -ForegroundColor Yellow
    Write-Host ""
    
    try {
        # Cache Prism Central admin password
        Write-Host "1. Caching Prism Central admin password..." -ForegroundColor Cyan
        $adminPassword = Get-CachedPassword -Username "admin" -ForcePrompt
        if ($adminPassword) {
            Write-Host "✓ Admin password cached successfully" -ForegroundColor Green
        }
        
        # Cache VM administrator password
        Write-Host "`n2. Caching VM administrator password..." -ForegroundColor Cyan
        $vmAdminPassword = Get-CachedPassword -Username "vm-administrator" -ForcePrompt
        if ($vmAdminPassword) {
            Write-Host "✓ VM administrator password cached successfully" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "🎉 Password caching complete!" -ForegroundColor Green
        Write-Host "   You can now run deployments with minimal password prompts." -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "  • Run: .\Deploy-AutoWindows.ps1 -NonInteractive" -ForegroundColor White
        Write-Host "  • Or:  .\Deploy-AutoWindows.ps1 (for normal deployment)" -ForegroundColor White
        Write-Host ""
        
    } catch {
        Write-Host ""
        Write-Host "❌ Password caching failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
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

function Get-PrismCentralIP {
    <#
    .SYNOPSIS
    Get Prism Central IP address from configuration
    
    .PARAMETER ConfigPath
    Path to deployment configuration file
    
    .OUTPUTS
    Returns Prism Central IP address
    #>
    param(
        [string]$ConfigPath = "config\deployment-config.json"
    )
    
    try {
        if (Test-Path $ConfigPath) {
            $config = Get-Content $ConfigPath | ConvertFrom-Json
            return $config.prismCentral.ip
        }
        else {
            Write-Warning "Configuration file not found: $ConfigPath"
            return "10.38.10.138"  # Fallback default
        }
    }
    catch {
        Write-Warning "Failed to read Prism Central IP from config: $($_.Exception.Message)"
        return "10.38.10.138"  # Fallback default
    }
}

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

function Get-VMIPAddressFromDeployment {
    param(
        [string]$VMUUID,
        [string]$VMName,
        [int]$MaxWaitMinutes = 5,
        [int]$RetryIntervalSeconds = 30
    )
    
    Write-Log "Starting IP discovery for VM: $VMName (UUID: $VMUUID)" -Level "INFO"
    
    $maxAttempts = [math]::Ceiling($MaxWaitMinutes * 60 / $RetryIntervalSeconds)
    $attempt = 1
    
    do {
        Write-Log "IP Discovery Attempt $attempt/$maxAttempts" -Level "INFO"
        
        try {
            # Use our enhanced Get-VMIPAddress script
            $ipScript = Join-Path $Script:ScriptRoot "Get-VMIPAddress.ps1"
            if (Test-Path $ipScript) {
                $ipResult = & $ipScript -VMUUID $VMUUID -MaxRetries 2 -RetryDelay 10
                
                Write-Log "Raw output from Get-VMIPAddress.ps1: $($ipResult -join "`n")" -Level "DEBUG"
                
                if ($ipResult) {
                    # Parse IP from result using our enhanced parsing
                    $discoveredIP = Parse-IPFromOutput -Output @($ipResult)
                    if ($discoveredIP) {
                        Write-Log "Successfully discovered VM IP: $discoveredIP" -Level "SUCCESS"
                        return $discoveredIP
                    } else {
                        Write-Log "Failed to parse IP from Get-VMIPAddress.ps1 output" -Level "WARN"
                    }
                } else {
                    Write-Log "No output received from Get-VMIPAddress.ps1" -Level "WARN"
                }
            }
            
            # If script method fails, try direct API call as backup
            Write-Log "Trying direct API fallback for IP discovery..." -Level "INFO"
            $directIP = Get-VMIPDirectAPI -VMUUID $VMUUID
            if ($directIP) {
                Write-Log "Direct API discovered VM IP: $directIP" -Level "SUCCESS"
                return $directIP
            }
            
        } catch {
            Write-Log "Error in IP discovery attempt $attempt : $($_.Exception.Message)" -Level "WARN"
        }
        
        if ($attempt -lt $maxAttempts) {
            Write-Log "No IP found yet. Waiting $RetryIntervalSeconds seconds before retry..." -Level "INFO"
            Start-Sleep -Seconds $RetryIntervalSeconds
        }
        
        $attempt++
        
    } while ($attempt -le $maxAttempts)
    
    Write-Log "Failed to discover VM IP address after $maxAttempts attempts" -Level "ERROR"
    return $null
}

function Test-VMReadinessAfterDeployment {
    param([object]$VMResult)
    
    try {
        Write-Log "Discovering VM IP address for readiness testing..." -Level "INFO"
        
        # Use our enhanced IP discovery mechanism
        $vmIPAddress = Get-VMIPAddressFromDeployment -VMUUID $VMResult.VMUUID -VMName $VMResult.VMName -MaxWaitMinutes 5
        
        if (-not $vmIPAddress) {
            Write-Log "Could not discover VM IP address for readiness testing" -Level "WARN"
            return @{ Success = $false; Message = "IP discovery failed" }
        }
        
        Write-Log "VM IP Address discovered: $vmIPAddress" -Level "INFO"
        
        # Wait 5 minutes for VM to fully boot and initialize before readiness testing
        Write-Log "Waiting 5 minutes for VM to fully boot and initialize before readiness testing..." -Level "INFO"
        Write-Log "This ensures Windows services, network stack, and remote management components are fully started" -Level "INFO"
        
        $waitMinutes = 5
        $waitSeconds = $waitMinutes * 60
        for ($i = 1; $i -le $waitSeconds; $i++) {
            $remaining = $waitSeconds - $i
            $remainingMinutes = [math]::Floor($remaining / 60)
            $remainingSecondsDisplay = $remaining % 60
            
            if ($i % 30 -eq 0 -or $remaining -le 60) {
                Write-Log "VM boot wait: ${remainingMinutes}:$($remainingSecondsDisplay.ToString('D2')) remaining..." -Level "INFO"
            }
            
            Start-Sleep -Seconds 1
        }
        
        Write-Log "VM boot wait completed - proceeding with readiness testing" -Level "SUCCESS"
        
        # Run Test-VMReadiness.ps1 with AddToTrusted parameter
        $testReadinessScript = Join-Path $Script:ScriptRoot "Test-VMReadiness.ps1"
        if (-not (Test-Path $testReadinessScript)) {
            Write-Log "Test-VMReadiness.ps1 not found at: $testReadinessScript" -Level "WARN"
            return @{ Success = $false; Message = "Test script not found"; IPAddress = $vmIPAddress }
        }
        
        Write-Log "Running VM readiness test with trusted hosts configuration..." -Level "INFO"
        
        # Execute Test-VMReadiness.ps1 with AddToTrusted parameter
        $readinessResult = & $testReadinessScript -VMIPAddress $vmIPAddress -AddToTrusted -TestLevel "Standard"
        
        if ($readinessResult -and $readinessResult.OverallResult -eq "PASS") {
            Write-Log "VM readiness test passed successfully" -Level "SUCCESS"
            return @{ 
                Success = $true; 
                IPAddress = $vmIPAddress; 
                ReadinessResult = $readinessResult 
            }
        } else {
            Write-Log "VM readiness test failed or incomplete" -Level "WARN"
            return @{ 
                Success = $false; 
                Message = "Readiness test failed"; 
                IPAddress = $vmIPAddress;
                ReadinessResult = $readinessResult
            }
        }
        
    } catch {
        Write-Log "Error during VM readiness testing: $($_.Exception.Message)" -Level "ERROR"
        return @{ Success = $false; Message = $_.Exception.Message }
    }
}

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
            
            # Test VM readiness as final Phase 1 step
            Write-Log "Testing VM readiness and adding to trusted hosts..." -Level "INFO"
            $vmReadinessResult = Test-VMReadinessAfterDeployment -VMResult $result
            if ($vmReadinessResult.Success) {
                Write-Log "VM readiness test passed - VM is ready for Phase 2" -Level "SUCCESS"
                Write-Log "VM IP Address: $($vmReadinessResult.IPAddress)" -Level "SUCCESS"
                $result.IPAddress = $vmReadinessResult.IPAddress
            } else {
                Write-Log "VM readiness test failed, but Phase 1 deployment was successful" -Level "WARN"
            }
            
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
        
        # Get VM IP address from Phase 1 results or discover it
        $vmIPAddress = $null
        if ($Phase1Results -and $Phase1Results.IPAddress) {
            $vmIPAddress = $Phase1Results.IPAddress
            Write-Log "Using VM IP from Phase 1 results: $vmIPAddress" -Level "INFO"
        } elseif ($Phase1Results -and $Phase1Results.VMUUID) {
            # Phase 1 completed but no IP yet - wait and discover it
            Write-Log "Phase 1 completed. Waiting for VM to get IP address..." -Level "INFO"
            $vmIPAddress = Wait-ForVMIPAddress -VMUUID $Phase1Results.VMUUID -VMName $Phase1Results.VMName
        } else {
            # Try to get IP from the Get-VMIPAddress script for standalone Phase 2
            Write-Log "Attempting to discover VM IP address..." -Level "INFO"
            $ipScript = Join-Path $Script:ScriptRoot "Get-VMIPAddress.ps1"
            if (Test-Path $ipScript) {
                try {
                    $vmIPAddress = Get-VMIPFromScript -ScriptPath $ipScript
                } catch {
                    Write-Log "Failed to get VM IP automatically: $($_.Exception.Message)" -Level "WARN"
                    if (!$NonInteractive) {
                        $vmIPAddress = Read-Host "Enter the VM IP address for Phase 2 setup"
                    }
                }
            } else {
                if (!$NonInteractive) {
                    $vmIPAddress = Read-Host "Enter the VM IP address for Phase 2 setup"
                }
            }
        }
        
        if (-not $vmIPAddress) {
            throw "VM IP address is required for Phase 2"
        }
        
        # Use the new Phase 2 API environment setup script
        $phase2Script = Join-Path $Script:ScriptRoot "Setup-Phase2-ApiEnvironment.ps1"
        if (!(Test-Path $phase2Script)) {
            throw "Phase 2 script not found: $phase2Script"
        }
        
        # Prepare Phase 2 parameters
        $phase2Params = @{
            VMIPAddress = $vmIPAddress
            UseHTTPS = $true  # Prefer HTTPS for security
        }
        
        Write-Log "Starting Phase 2 API environment setup..." -Level "INFO"
        Write-Log "Target VM: $vmIPAddress" -Level "INFO"
        Write-Log "Using HTTPS connection for security" -Level "INFO"
        Write-Log "Note: VM readiness testing will ensure all remote management requirements are properly configured" -Level "INFO"
        
        # Test VM readiness and ensure all remote management requirements are installed
        $readinessScript = Join-Path $Script:ScriptRoot "Test-VMReadiness.ps1"
        if (Test-Path $readinessScript) {
            Write-Log "Testing VM readiness and configuring remote management requirements..." -Level "INFO"
            Write-Log "This step ensures PowerShell remoting, WinRM, and all dependencies are properly configured" -Level "INFO"
            try {
                & $readinessScript -VMIPAddress $vmIPAddress -AddToTrusted -TestLevel "Full"
                Write-Log "VM readiness test completed successfully - all remote management requirements are configured" -Level "SUCCESS"
            } catch {
                Write-Log "VM readiness test failed: $($_.Exception.Message)" -Level "ERROR"
                Write-Log "Remote management configuration is required before Phase 2 can proceed" -Level "ERROR"
                throw "VM readiness validation failed - cannot proceed to Phase 2 without proper remote management setup"
            }
        } else {
            Write-Log "Test-VMReadiness.ps1 script not found - skipping VM readiness validation" -Level "WARN"
            Write-Log "Manual verification of PowerShell remoting and WinRM configuration may be required" -Level "WARN"
        }
        
        # Execute Phase 2 API environment setup
        Write-Log "Executing Phase 2 API environment installation..." -Level "INFO"
        & $phase2Script @phase2Params
        
        # Check if the execution was successful (the script should exit with 0 on success)
        if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
            $Script:ExecutionResults.Phase2.Success = $true
            $Script:ExecutionResults.Phase2.Results = @{
                VMIPAddress = $vmIPAddress
                EnvironmentInstalled = $true
                RepositoryCloned = $true
                Message = "Nutanix v4 API development environment successfully installed"
            }
            Write-Log "Phase 2 completed successfully!" -Level "SUCCESS"
            return $Script:ExecutionResults.Phase2.Results
        } else {
            throw "Phase 2 execution failed with exit code: $LASTEXITCODE"
        }
    }
    catch {
        $Script:ExecutionResults.Phase2.Success = $false
        Write-Log "Phase 2 failed: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Wait-ForVMIPAddress {
    param(
        [string]$VMUUID,
        [string]$VMName,
        [int]$MaxWaitMinutes = 15,
        [int]$RetryIntervalSeconds = 30
    )
    
    Write-Log "Waiting for VM to obtain IP address..." -Level "INFO"
    Write-Log "VM UUID: $VMUUID" -Level "DEBUG"
    Write-Log "VM Name: $VMName" -Level "DEBUG"
    Write-Log "Max wait time: $MaxWaitMinutes minutes" -Level "DEBUG"
    
    $maxAttempts = [math]::Ceiling($MaxWaitMinutes * 60 / $RetryIntervalSeconds)
    $attempt = 1
    
    do {
        Write-Log "Attempt $attempt/$maxAttempts - Checking for IP address..." -Level "INFO"
        
        try {
            $ipScript = Join-Path $Script:ScriptRoot "Get-VMIPAddress.ps1"
            if (Test-Path $ipScript) {
                # Run IP discovery directly (not in background job to allow user interaction)
                Write-Log "Starting IP discovery attempt $attempt..." -Level "INFO"
                
                try {
                    # Run the script directly and capture output
                    $ipResult = & $ipScript -VMUUID $VMUUID -MaxRetries 1 -RetryDelay 5
                    
                    # Debug: Show raw output
                    Write-Log "Raw output from Get-VMIPAddress.ps1:" -Level "DEBUG"
                    foreach ($line in $ipResult) {
                        Write-Log "  '$line'" -Level "DEBUG"
                    }
                    
                    # Parse the output for IP address
                    $ipAddress = Parse-IPFromOutput -Output $ipResult
                    
                    if ($ipAddress) {
                        Write-Log "VM IP address discovered: $ipAddress" -Level "SUCCESS"
                        return $ipAddress
                    } else {
                        Write-Log "No IP address found in attempt $attempt" -Level "DEBUG"
                    }
                } catch {
                    Write-Log "Error during IP discovery: $($_.Exception.Message)" -Level "WARN"
                }
            }
            
            Write-Log "IP address not yet available. VM may still be booting..." -Level "INFO"
            
            if ($attempt -lt $maxAttempts) {
                Write-Log "Waiting $RetryIntervalSeconds seconds before next attempt..." -Level "INFO"
                Start-Sleep -Seconds $RetryIntervalSeconds
            }
            
        } catch {
            Write-Log "Error during IP discovery attempt: $($_.Exception.Message)" -Level "WARN"
            if ($attempt -lt $maxAttempts) {
                Start-Sleep -Seconds $RetryIntervalSeconds
            }
        }
        
        $attempt++
        
    } while ($attempt -le $maxAttempts)
    
    Write-Log "Timeout: VM IP address not available after $MaxWaitMinutes minutes" -Level "WARN"
    Write-Log "This is normal for Windows VMs which can take 10-15 minutes to fully boot" -Level "INFO"
    
    if (!$NonInteractive) {
        Write-Log "You can find the VM IP address by:" -Level "INFO"
        Write-Log "  1. Opening Prism Central: https://$(Get-PrismCentralIP):9440" -Level "INFO"
        Write-Log "  2. Going to VMs → $VMName → Network tab" -Level "INFO"
        Write-Log "  3. Checking the VM console for network configuration" -Level "INFO"
        Write-Log "  4. Using ping or network scanning tools" -Level "INFO"
        
        $manualIP = Read-Host "Enter the VM IP address manually (or press Enter to continue waiting)"
        if ($manualIP) {
            # Validate IP format
            if ($manualIP -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
                Write-Log "Using manually entered IP: $manualIP" -Level "SUCCESS"
                return $manualIP
            } else {
                Write-Log "Invalid IP format entered: $manualIP" -Level "WARN"
                Write-Log "Expected format: x.x.x.x (e.g., 10.38.19.214)" -Level "INFO"
            }
        }
        
        # Extended wait if user chooses
        $continueWait = Read-Host "Continue waiting for automatic IP discovery? (Y/n)"
        if ($continueWait -notmatch "^[Nn]") {
            return Wait-ForVMIPAddress -VMUUID $VMUUID -VMName $VMName -MaxWaitMinutes 10
        }
    }
    
    return $null
}

function Parse-IPFromOutput {
    param([string[]]$Output)
    
    Write-Log "=== IP PARSING DEBUG ===" -Level "DEBUG"
    Write-Log "Total lines to parse: $($Output.Count)" -Level "DEBUG"
    
    # Look for IP address pattern in output with comprehensive matching
    foreach ($line in $Output) {
        Write-Log "Parsing line: '$line'" -Level "DEBUG"
        
        # Check if line contains an IP address at all
        if ($line -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}") {
            Write-Log "Line contains IP pattern: '$line'" -Level "DEBUG"
            
            # Extract any IP address from the line - most permissive approach
            if ($line -match "(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})") {
                $foundIP = $matches[1]
                Write-Log "Extracted IP: $foundIP" -Level "DEBUG"
                
                # Basic IP validation - exclude obviously invalid IPs
                $octets = $foundIP.Split('.')
                $validIP = $true
                foreach ($octet in $octets) {
                    if ([int]$octet -gt 255) {
                        $validIP = $false
                        break
                    }
                }
                
                if ($validIP) {
                    Write-Log "Valid IP found: $foundIP" -Level "SUCCESS"
                    return $foundIP
                }
            }
        }
    }
    
    Write-Log "=== NO IP FOUND IN OUTPUT ===" -Level "WARN"
    return $null
}

function Get-VMIPDirectAPI {
    param([string]$VMUUID)
    
    try {
        Write-Log "Attempting direct Prism Central API call for VM: $VMUUID" -Level "INFO"
        
        # Get cached admin password using proper function call
        try {
            Import-Module (Join-Path $Script:ScriptRoot "PasswordManager.ps1") -Force
            $adminPassword = Get-CachedPassword -Username "admin"
            if (-not $adminPassword -or $adminPassword -eq "No password found") {
                Write-Log "No cached password available for direct API call" -Level "WARN"
                return $null
            }
        } catch {
            Write-Log "Failed to get cached password: $($_.Exception.Message)" -Level "WARN"
            return $null
        }
        
        # Direct API call
        $base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:$adminPassword"))
        $headers = @{
            "Authorization" = "Basic $base64Auth"
            "Content-Type" = "application/json"
            "Accept" = "application/json"
        }
        
        $uri = "https://$(Get-PrismCentralIP):9440/api/nutanix/v3/vms/$VMUUID"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -SkipCertificateCheck -TimeoutSec 30
        
        # Extract IP from response
        $nicList = $response.status.resources.nic_list
        if ($nicList -and $nicList[0].ip_endpoint_list) {
            $ipAddress = $nicList[0].ip_endpoint_list[0].ip
            if ($ipAddress) {
                Write-Log "Direct API discovered IP: $ipAddress" -Level "SUCCESS"
                return $ipAddress
            }
        }
        
        Write-Log "No IP found in direct API response" -Level "WARN"
        return $null
        
    } catch {
        Write-Log "Direct API call failed: $($_.Exception.Message)" -Level "WARN"
        return $null
    }
}

function Get-VMIPFromScript {
    param([string]$ScriptPath)
    
    Write-Log "Executing Get-VMIPAddress script..." -Level "INFO"
    
    $output = & $ScriptPath 2>&1
    $ipAddress = Parse-IPFromOutput -Output $output
    
    if ($ipAddress) {
        Write-Log "IP address discovered: $ipAddress" -Level "SUCCESS"
        return $ipAddress
    } else {
        throw "Could not parse IP address from script output"
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
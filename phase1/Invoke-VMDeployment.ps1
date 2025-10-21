<#
.SYNOPSIS
    VM Deployment Process Wrapper

.DESCRIPTION
    Wraps and executes the Python-based VM deployment process from the 
    deploy_win_vm_v1 repository. Handles both phases of the deployment:
    1. Resource Selection
    2. VM Deployment

.NOTES
    Author: Hardev Sanghera
    Date: October 2025
#>

function Invoke-VMDeploymentProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath,
        
        [Parameter(Mandatory = $true)]
        [object]$Config,
        
        [Parameter(Mandatory = $false)]
        [string]$PythonExe = "python"
    )
    
    Write-Host "=== VM DEPLOYMENT PROCESS ===" -ForegroundColor Cyan
    
    try {
        Push-Location $RepoPath
        
        # Verify required files exist
        $requiredFiles = @("deploy_win_vm.py", "create_vm_SKEL.json", "requirements.txt")
        foreach ($file in $requiredFiles) {
            if (!(Test-Path $file)) {
                throw "Required file not found: $file"
            }
        }
        
        Write-Host "Repository files verified" -ForegroundColor Green
        
        # Activate Python virtual environment
        if (Test-Path "venv\Scripts\Activate.ps1") {
            Write-Host "Activating Python virtual environment..." -ForegroundColor Cyan
            & "venv\Scripts\Activate.ps1"
        }
        
        # Execute deployment process based on configuration
        if ($Config.deployment.mode -eq "interactive") {
            return Invoke-InteractiveDeployment -Config $Config
        }
        else {
            return Invoke-AutomatedDeployment -Config $Config
        }
    }
    catch {
        Write-Host "VM deployment process failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
    finally {
        Pop-Location
    }
}

function Invoke-InteractiveDeployment {
    param([object]$Config)
    
    Write-Host "Starting interactive VM deployment..." -ForegroundColor Cyan
    
    # Phase 1: Resource Selection
    Write-Host "=== PHASE 1: Resource Selection ===" -ForegroundColor Yellow
    
    $pcIp = $Config.prismCentral.ip
    $username = $Config.prismCentral.username
    
    if (!$pcIp -or !$username) {
        throw "Prism Central IP and username must be configured"
    }
    
    Write-Host "Connecting to Prism Central: $pcIp as $username" -ForegroundColor Cyan
    
    # Execute resource selection
    $resourceSelectionArgs = @("deploy_win_vm.py", $pcIp, $username)
    $process = Start-Process -FilePath $PythonExe -ArgumentList $resourceSelectionArgs -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -ne 0) {
        throw "Resource selection failed with exit code: $($process.ExitCode)"
    }
    
    Write-Host "Resource selection completed successfully" -ForegroundColor Green
    
    # Verify deployment_config.json was created
    if (!(Test-Path "deployment_config.json")) {
        throw "Deployment configuration file was not created"
    }
    
    # Phase 2: VM Deployment
    Write-Host "=== PHASE 2: VM Deployment ===" -ForegroundColor Yellow
    
    # Get VM name from configuration or generate one
    $vmName = Get-VMName -Config $Config
    Write-Host "VM Name: $vmName" -ForegroundColor Cyan
    
    # Get admin password
    $adminPassword = Get-AdminPassword -Config $Config
    
    # Get Prism Central password using password manager
    . (Join-Path $PSScriptRoot "..\PasswordManager.ps1")
    Write-Host "Prism Central Password:" -ForegroundColor Cyan
    $pcSecurePassword = Get-AdminPassword -Username $Config.prismCentral.username
    $pcPassword = ""
    if ($pcSecurePassword) {
        $pcPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pcSecurePassword))
    }
    
    # Create automation input file for VM deployment
    $automationFile = Join-Path $WorkingDirectory "vm_automation_input.json"
    $automationData = @{
        vm_name = $vmName
        admin_password = $adminPassword
        confirm_password = $adminPassword
        pc_password = $pcPassword
        proceed_deployment = "y"
    }
    $automationData | ConvertTo-Json | Set-Content $automationFile
    
    # Execute VM deployment with automation support
    Write-Host "Deploying VM: $vmName" -ForegroundColor Cyan
    
    # Set environment variable to indicate automated mode
    $env:VM_AUTOMATION_FILE = $automationFile
    
    try {
        # Copy enhanced automation wrapper to deployment directory
        $automationWrapper = Join-Path $PSScriptRoot "..\deploy_vm_automated_v4.py"
        $deploymentDir = Join-Path $WorkingDirectory "repos\deploy_win_vm_v1"
        $wrapperDestination = Join-Path $deploymentDir "deploy_vm_automated.py"
        
        Copy-Item $automationWrapper $wrapperDestination -Force
        
        # Use virtual environment Python instead of global Python
        $venvPython = Join-Path $deploymentDir "venv\Scripts\python.exe"
        if (-not (Test-Path $venvPython)) {
            throw "Virtual environment Python not found at: $venvPython"
        }
        
        # Run the enhanced automation wrapper with virtual environment Python and capture output
        $deployProcess = Start-Process -FilePath $venvPython -ArgumentList "deploy_vm_automated.py" -Wait -PassThru -NoNewWindow -WorkingDirectory $deploymentDir -RedirectStandardOutput "deployment_output.txt" -RedirectStandardError "deployment_error.txt"
        
        # Clean up automation file and environment variable after process completes
        if (Test-Path $automationFile) { Remove-Item $automationFile -Force }
        Remove-Item Env:VM_AUTOMATION_FILE -ErrorAction SilentlyContinue
    }
    finally {
        # Ensure cleanup in case of exceptions
        if (Test-Path $automationFile) { Remove-Item $automationFile -Force -ErrorAction SilentlyContinue }
        Remove-Item Env:VM_AUTOMATION_FILE -ErrorAction SilentlyContinue
    }
    
    if ($deployProcess.ExitCode -eq 0) {
        # Read captured output files
        $outputFile = Join-Path $deploymentDir "deployment_output.txt"
        $errorFile = Join-Path $deploymentDir "deployment_error.txt"
        
        $capturedOutput = ""
        if (Test-Path $outputFile) {
            $capturedOutput = Get-Content $outputFile -Raw
            Write-Host $capturedOutput
        }
        
        $capturedErrors = ""
        if (Test-Path $errorFile) {
            $capturedErrors = Get-Content $errorFile -Raw
            if ($capturedErrors) {
                Write-Host "Deployment Errors:" -ForegroundColor Yellow
                Write-Host $capturedErrors -ForegroundColor Red
            }
        }
        
        # Parse deployment results from captured output
        $result = Parse-DeploymentResults -LogOutput $capturedOutput
        
        Write-Host "VM deployment completed successfully!" -ForegroundColor Green
        Write-Host "VM UUID: $($result.VMUUID)" -ForegroundColor Green
        Write-Host "Task UUID: $($result.TaskUUID)" -ForegroundColor Green
        
        return @{
            Success = $true
            VMName = $vmName
            VMUUID = $result.VMUUID
            TaskUUID = $result.TaskUUID
            DeploymentTime = Get-Date
        }
    }
    else {
        throw "VM deployment failed with exit code: $($deployProcess.ExitCode)"
    }
}

function Invoke-AutomatedDeployment {
    param([object]$Config)
    
    Write-Host "Automated deployment not yet implemented" -ForegroundColor Yellow
    Write-Host "Please use interactive mode for now" -ForegroundColor Yellow
    
    return @{
        Success = $false
        Error = "Automated deployment not implemented"
    }
}

function Get-VMName {
    param([object]$Config)
    
    # Check if VM name is specified in config
    if ($Config.vmConfiguration.namePrefix) {
        $prefix = $Config.vmConfiguration.namePrefix
        $timestamp = Get-Date -Format "MMdd-HHmm"
        $fullName = "$prefix$timestamp"
        
        # Ensure VM name doesn't exceed 15 characters (Windows computer name limit)
        if ($fullName.Length -gt 15) {
            # Truncate prefix and add shorter timestamp
            $shortTimestamp = Get-Date -Format "MMdd"
            $maxPrefixLength = 15 - $shortTimestamp.Length
            $truncatedPrefix = $prefix.Substring(0, [Math]::Min($prefix.Length, $maxPrefixLength))
            $fullName = "$truncatedPrefix$shortTimestamp"
            
            # If still too long, use a more aggressive approach
            if ($fullName.Length -gt 15) {
                $shortTimestamp = Get-Date -Format "Hmm"  # Hour + minute
                $maxPrefixLength = 15 - $shortTimestamp.Length
                $truncatedPrefix = $prefix.Substring(0, [Math]::Min($prefix.Length, $maxPrefixLength))
                $fullName = "$truncatedPrefix$shortTimestamp"
            }
        }
        
        return $fullName
    }
    
    # Prompt for VM name
    do {
        $vmName = Read-Host "Enter VM name (max 15 characters, alphanumeric + hyphens/underscores)"
        if ($vmName.Length -gt 15) {
            Write-Host "VM name too long. Maximum 15 characters." -ForegroundColor Red
            continue
        }
        if ($vmName -notmatch '^[a-zA-Z0-9_-]+$') {
            Write-Host "VM name contains invalid characters. Use alphanumeric, hyphens, or underscores only." -ForegroundColor Red
            continue
        }
        break
    } while ($true)
    
    return $vmName
}

function Get-AdminPassword {
    param([object]$Config)
    
    # Check if password is specified in config
    if ($Config.vmConfiguration.adminPassword) {
        return $Config.vmConfiguration.adminPassword
    }
    
    # Import password manager
    . (Join-Path $PSScriptRoot "..\PasswordManager.ps1")
    
    # Use password manager for VM admin password
    Write-Host "VM Administrator Password:" -ForegroundColor Cyan
    $securePassword = Get-AdminPassword -Username "vm-administrator"
    
    if ($securePassword) {
        return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
    }
    
    # Fallback to manual prompt if password manager fails
    Write-Host "⚠️  Password manager unavailable, using manual entry" -ForegroundColor Yellow
    do {
        $password = Read-Host "Enter Administrator password (minimum 4 characters)" -AsSecureString
        $confirmPassword = Read-Host "Confirm Administrator password" -AsSecureString
        
        # Convert to plain text for comparison
        $pwd1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
        $pwd2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmPassword))
        
        if ($pwd1.Length -lt 4) {
            Write-Host "Password too short. Minimum 4 characters required." -ForegroundColor Red
            continue
        }
        
        if ($pwd1 -ne $pwd2) {
            Write-Host "Passwords do not match. Please try again." -ForegroundColor Red
            continue
        }
        
        return $pwd1
    } while ($true)
}

function Parse-DeploymentResults {
    param([string]$LogOutput)
    
    # Parse VM and Task UUIDs from the output
    $vmUuid = $null
    $taskUuid = $null
    
    if ($LogOutput -match "VM UUID:\s+([a-fA-F0-9-]+)") {
        $vmUuid = $matches[1]
    }
    
    if ($LogOutput -match "Task UUID:\s+([a-fA-F0-9-]+)") {
        $taskUuid = $matches[1]
    }
    
    return @{
        VMUUID = $vmUuid
        TaskUUID = $taskUuid
    }
}

function Wait-ForVMDeployment {
    param(
        [string]$TaskUUID,
        [object]$Config,
        [int]$TimeoutSeconds = 1800
    )
    
    Write-Host "Monitoring VM deployment progress..." -ForegroundColor Cyan
    Write-Host "Task UUID: $TaskUUID" -ForegroundColor Gray
    
    $startTime = Get-Date
    $checkInterval = $Config.monitoring.checkInterval -or 30
    
    while (((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
        Write-Host "Checking deployment status..." -ForegroundColor Gray
        
        # Here you would implement actual API calls to check task status
        # For now, we'll simulate the check
        Start-Sleep $checkInterval
        
        # This is a placeholder - in a real implementation, you'd query the Nutanix API
        # to check the task status using the Task UUID
        Write-Host "Task still in progress..." -ForegroundColor Gray
    }
    
    Write-Host "Deployment monitoring completed" -ForegroundColor Green
    return $true
}
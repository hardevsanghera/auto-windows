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
    
    # Prepare deployment inputs
    $deploymentInputs = @"
$vmName
$adminPassword
$adminPassword
y

"@
    
    # Write inputs to temp file first
    $deploymentInputs | Set-Content "$env:TEMP\deployment_input.txt"
    
    # Execute VM deployment
    Write-Host "Deploying VM: $vmName" -ForegroundColor Cyan
    $deployProcess = Start-Process -FilePath $PythonExe -ArgumentList "deploy_win_vm.py", "--deploy" -Wait -PassThru -NoNewWindow -RedirectStandardInput "$env:TEMP\deployment_input.txt"
    
    if ($deployProcess.ExitCode -eq 0) {
        # Parse deployment results
        $result = Parse-DeploymentResults -LogOutput $deploymentOutput
        
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
        return "$prefix$timestamp"
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
    
    # Prompt for password securely
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
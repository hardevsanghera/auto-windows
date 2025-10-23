<#
.SYNOPSIS
    Phase 1: Windows VM Deployment using deploy_win_vm_v1 repository

.DESCRIPTION
    This script handles the complete Phase 1 workflow:
    1. Downloads/clones the deploy_win_vm_v1 repository
    2. Sets up Python environment and dependencies
    3. Executes the VM deployment process (resource selection and deployment)
    4. Monitors deployment progress
    5. Prepares for Phase 2 execution

.PARAMETER ConfigPath
    Path to the deployment configuration file

.PARAMETER LogPath
    Path to write execution logs

.PARAMETER WorkingDirectory
    Directory for temporary files and repositories

.EXAMPLE
    .\Initialize-VMDeployment.ps1 -ConfigPath "config\deployment-config.json"

.NOTES
    Author: Hardev Sanghera
    Date: October 2025
    Requires: PowerShell 7+, Internet connectivity
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "config\deployment-config.json",
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "logs\phase1.log",
    
    [Parameter(Mandatory = $false)]
    [string]$WorkingDirectory = "temp"
)

# Import required modules and functions
. "$PSScriptRoot\Get-ExternalRepo.ps1"
. "$PSScriptRoot\Invoke-VMDeployment.ps1"

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

function Test-Prerequisites {
    Write-Log "Checking Phase 1 prerequisites..."
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Log "PowerShell 7+ is required. Current version: $($PSVersionTable.PSVersion)" -Level "ERROR"
        return $false
    }
    
    # Check Python availability
    try {
        $pythonVersion = python --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $pythonVersion -match "Python \d+\.\d+") {
            Write-Log "Python found: $pythonVersion" -Level "SUCCESS"
        }
        else {
            Write-Log "Python not found in PATH. Error: $pythonVersion" -Level "WARN"
        }
    }
    catch {
        Write-Log "Python not found in PATH. Will attempt installation." -Level "WARN"
    }
    
    # Check Git availability
    try {
        $gitVersion = git --version 2>&1
        Write-Log "Git found: $gitVersion" -Level "SUCCESS"
    }
    catch {
        Write-Log "Git not found in PATH. Will attempt installation." -Level "WARN"
    }
    
    # Check internet connectivity
    try {
        Test-Connection -ComputerName "github.com" -Count 1 -ErrorAction Stop | Out-Null
        Write-Log "Internet connectivity verified" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Internet connectivity check failed: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Initialize-WorkingDirectory {
    param([string]$Path)
    
    Write-Log "Initializing working directory: $Path"
    
    try {
        if (!(Test-Path $Path)) {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-Log "Created working directory: $Path" -Level "SUCCESS"
        }
        
        # Create subdirectories
        $subDirs = @("repos", "logs", "temp", "output")
        foreach ($subDir in $subDirs) {
            $fullPath = Join-Path $Path $subDir
            if (!(Test-Path $fullPath)) {
                New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
            }
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to initialize working directory: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Read-DeploymentConfig {
    param([string]$ConfigFile)
    
    Write-Log "Reading deployment configuration from: $ConfigFile"
    
    try {
        if (!(Test-Path $ConfigFile)) {
            Write-Log "Configuration file not found: $ConfigFile" -Level "ERROR"
            return $null
        }
        
        $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        Write-Log "Configuration loaded successfully" -Level "SUCCESS"
        return $config
    }
    catch {
        Write-Log "Failed to read configuration: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Install-PythonDependencies {
    param([string]$RepoPath)
    
    Write-Log "Setting up Python environment for VM deployment..."
    
    # Find Python executable - check multiple locations
    $pythonPaths = @(
        "C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python313\python.exe",
        "C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python312\python.exe",
        "C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python311\python.exe",
        "C:\Python313\python.exe",
        "C:\Python312\python.exe",
        "C:\Python311\python.exe"
    )
    
    $pythonExe = $null
    foreach ($path in $pythonPaths) {
        if (Test-Path $path) {
            try {
                $version = & $path --version 2>&1
                if ($LASTEXITCODE -eq 0 -and $version -match "Python \d+\.\d+") {
                    $pythonExe = $path
                    Write-Log "Found Python: $version at $path" -Level "SUCCESS"
                    break
                }
            }
            catch {
                continue
            }
        }
    }
    
    if (-not $pythonExe) {
        # Try system PATH as fallback
        try {
            $version = python --version 2>&1
            if ($LASTEXITCODE -eq 0 -and $version -match "Python \d+\.\d+") {
                $pythonExe = "python"
                Write-Log "Found Python in PATH: $version" -Level "SUCCESS"
            }
        }
        catch {
            # Ignore
        }
    }
    
    if (-not $pythonExe) {
        Write-Log "Python is not available. Please install Python 3.7+ first." -Level "ERROR"
        Write-Log "Download from: https://www.python.org/downloads/" -Level "ERROR"
        return @{ Success = $false; PythonExe = $null }
    }
    
    try {
        Push-Location $RepoPath
        
        # Check if requirements.txt exists in the VM deployment repo
        if (Test-Path "requirements.txt") {
            Write-Log "Found requirements.txt, installing dependencies..."
            
            # Create virtual environment if it doesn't exist
            if (!(Test-Path "venv")) {
                Write-Log "Creating Python virtual environment..."
                & $pythonExe -m venv venv
                if ($LASTEXITCODE -ne 0) {
                    Write-Log "Failed to create virtual environment" -Level "ERROR"
                    return $false
                }
            }
            
            # Activate virtual environment and install dependencies
            if (Test-Path "venv\Scripts\Activate.ps1") {
                Write-Log "Activating virtual environment..."
                
                # Use the virtual environment Python for installations
                $venvPython = Join-Path $RepoPath "venv\Scripts\python.exe"
                if (-not (Test-Path $venvPython)) {
                    Write-Log "Virtual environment Python not found at: $venvPython" -Level "ERROR"
                    return @{ Success = $false; PythonExe = $null }
                }
                
                Write-Log "Installing Python dependencies..."
                & $venvPython -m pip install --upgrade pip
                & $venvPython -m pip install -r requirements.txt
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Python environment setup completed" -Level "SUCCESS"
                    return @{ Success = $true; PythonExe = $venvPython }
                } else {
                    Write-Log "Failed to install dependencies" -Level "ERROR"
                    return @{ Success = $false; PythonExe = $null }
                }
            }
            else {
                Write-Log "Virtual environment activation script not found" -Level "ERROR"
                return @{ Success = $false; PythonExe = $null }
            }
        }
        else {
            Write-Log "requirements.txt not found in repository" -Level "WARN"
            return @{ Success = $false; PythonExe = $null }
        }
    }
    catch {
        Write-Log "Failed to setup Python environment: $($_.Exception.Message)" -Level "ERROR"
        return @{ Success = $false; PythonExe = $null }
    }
    finally {
        Pop-Location
    }
}

function Start-Phase1Deployment {
    param($Config)
    
    Write-Log "=== STARTING PHASE 1: VM DEPLOYMENT ===" -Level "SUCCESS"
    
    # Initialize working directory
    if (!(Initialize-WorkingDirectory $WorkingDirectory)) {
        throw "Failed to initialize working directory"
    }
    
    # Clone or update the VM deployment repository
    $repoUrl = "https://github.com/hardevsanghera/deploy_win_vm_v1.git"
    $repoPath = Join-Path $WorkingDirectory "repos\deploy_win_vm_v1"
    
    Write-Log "Cloning VM deployment repository..."
    if (!(Get-ExternalRepository -RepoUrl $repoUrl -LocalPath $repoPath)) {
        throw "Failed to clone VM deployment repository"
    }
    
    # Setup Python environment
    $pythonSetup = Install-PythonDependencies -RepoPath $repoPath
    if (!$pythonSetup.Success) {
        throw "Failed to setup Python environment"
    }
    
    # Execute VM deployment
    Write-Log "Starting VM deployment process..."
    $deploymentResult = Invoke-VMDeploymentProcess -RepoPath $repoPath -Config $Config -PythonExe $pythonSetup.PythonExe
    
    if ($deploymentResult.Success) {
        Write-Log "Phase 1 completed successfully!" -Level "SUCCESS"
        Write-Log "VM UUID: $($deploymentResult.VMUUID)" -Level "SUCCESS"
        Write-Log "Task UUID: $($deploymentResult.TaskUUID)" -Level "SUCCESS"
        
        # Save deployment results for Phase 2
        $resultPath = Join-Path $WorkingDirectory "phase1-results.json"
        $deploymentResult | ConvertTo-Json -Depth 5 | Set-Content $resultPath
        Write-Log "Phase 1 results saved to: $resultPath" -Level "SUCCESS"
        
        return $deploymentResult
    }
    else {
        throw "VM deployment failed: $($deploymentResult.Error)"
    }
}

# Main execution
try {
    Write-Log "=== PHASE 1 INITIALIZATION ===" -Level "SUCCESS"
    
    # Check prerequisites
    if (!(Test-Prerequisites)) {
        throw "Prerequisites check failed"
    }
    
    # Read configuration
    $config = Read-DeploymentConfig -ConfigFile $ConfigPath
    if (!$config) {
        throw "Failed to load deployment configuration"
    }
    
    # Add WorkingDirectory to config object
    $config | Add-Member -NotePropertyName "WorkingDirectory" -NotePropertyValue $WorkingDirectory -Force
    
    # Start Phase 1 deployment
    $result = Start-Phase1Deployment -Config $config
    
    Write-Log "Phase 1 completed successfully. Ready for Phase 2." -Level "SUCCESS"
    return $result
}
catch {
    Write-Log "Phase 1 failed: $($_.Exception.Message)" -Level "ERROR"
    throw
}
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Phase 2: Install Nutanix v4 API Development Environment

.DESCRIPTION
    Clones the ntnx-v4api-cats repository and runs the experimental installation script
    to set up everything needed for Nutanix v4 API development and testing.

.PARAMETER VMIPAddress
    IP address of the target VM

.PARAMETER VMCredential
    Credentials for the VM (if not provided, will use cached credentials)

.PARAMETER UseHTTPS
    Use HTTPS PowerShell remoting instead of HTTP

.PARAMETER RepositoryURL
    URL of the repository to clone (defaults to ntnx-v4api-cats)

.EXAMPLE
    .\Deploy-AutoWindows.ps1 -phase 2

.EXAMPLE
    .\Setup-Phase2-ApiEnvironment.ps1 -VMIPAddress 10.38.19.22

.EXAMPLE
    .\Setup-Phase2-ApiEnvironment.ps1 -VMIPAddress 10.38.19.22 -UseHTTPS
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$VMIPAddress = "10.38.19.22",
    
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$VMCredential,
    
    [Parameter(Mandatory = $false)]
    [switch]$UseHTTPS,
    
    [Parameter(Mandatory = $false)]
    [string]$RepositoryURL = "https://github.com/hardevsanghera/ntnx-v4api-cats.git"
)

# Import password manager for getting VM credentials
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptRoot "PasswordManager.ps1") -Force

function Write-PhaseHeader {
    param([string]$Title)
    Write-Host "`n" + ("=" * 80) -ForegroundColor Magenta
    Write-Host "  $Title" -ForegroundColor Magenta
    Write-Host ("=" * 80) -ForegroundColor Magenta
}

function Write-StepResult {
    param(
        [string]$StepName,
        [bool]$Success,
        [string]$Details = "",
        [string]$Error = ""
    )
    
    $status = if ($Success) { "✓ SUCCESS" } else { "✗ FAILED" }
    $color = if ($Success) { "Green" } else { "Red" }
    
    Write-Host "[$status] $StepName" -ForegroundColor $color
    if ($Details) {
        Write-Host "    $Details" -ForegroundColor Gray
    }
    if ($Error -and -not $Success) {
        Write-Host "    Error: $Error" -ForegroundColor Red
    }
}

function Get-VMCredentials {
    Write-Host "`n🔐 Getting VM Credentials..." -ForegroundColor Cyan
    
    # Try to get cached VM administrator password
    $vmPassword = Get-CachedPassword -Username "vm-administrator"
    
    if ($vmPassword) {
        Write-Host "✓ Using cached password for: vm-administrator" -ForegroundColor Green
        
        # Handle both SecureString and plain text passwords
        if ($vmPassword -is [System.Security.SecureString]) {
            $securePassword = $vmPassword
        } else {
            $securePassword = ConvertTo-SecureString $vmPassword -AsPlainText -Force
        }
        
        return New-Object System.Management.Automation.PSCredential("Administrator", $securePassword)
    } else {
        Write-Host "[INFO] No cached VM password found. Please enter credentials." -ForegroundColor Yellow
        return Get-Credential -UserName "Administrator" -Message "Enter credentials for VM Administrator"
    }
}

function Test-VMConnectivity {
    param([string]$IPAddress, [System.Management.Automation.PSCredential]$Credential, [bool]$UseHTTPS)
    
    Write-Host "`n🔍 Testing VM Connectivity..." -ForegroundColor Cyan
    
    try {
        $sessionOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck
        $connectionParams = @{
            ComputerName = $IPAddress
            Credential = $Credential
            SessionOption = $sessionOptions
            ErrorAction = "Stop"
        }
        
        if ($UseHTTPS) {
            $connectionParams.Port = 5986
            $connectionParams.UseSSL = $true
            Write-Host "   Attempting HTTPS connection (port 5986)..." -ForegroundColor Gray
        } else {
            $connectionParams.Port = 5985
            Write-Host "   Attempting HTTP connection (port 5985)..." -ForegroundColor Gray
        }
        
        $testSession = New-PSSession @connectionParams
        
        if ($testSession) {
            $vmInfo = Invoke-Command -Session $testSession -ScriptBlock {
                [PSCustomObject]@{
                    ComputerName = $env:COMPUTERNAME
                    OSVersion = (Get-ComputerInfo).WindowsProductName
                    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                    FreeSpaceGB = [math]::Round((Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace / 1GB, 2)
                }
            }
            
            Remove-PSSession -Session $testSession
            
            Write-StepResult "VM Connectivity Test" $true "Connected to $($vmInfo.ComputerName) - $($vmInfo.OSVersion)"
            Write-Host "    PowerShell: $($vmInfo.PowerShellVersion)" -ForegroundColor Gray
            Write-Host "    Free Space: $($vmInfo.FreeSpaceGB) GB" -ForegroundColor Gray
            
            return $true
        }
        
    } catch {
        Write-StepResult "VM Connectivity Test" $false "" $_.Exception.Message
        return $false
    }
}

function Install-GitOnVM {
    param([object]$Session)
    
    Write-Host "`n📦 Installing Git on VM..." -ForegroundColor Cyan
    
    $gitInstallResult = Invoke-Command -Session $Session -ScriptBlock {
        $results = @{
            GitInstalled = $false
            GitVersion = ""
            InstallMethod = ""
            Error = ""
        }
        
        try {
            # Check if Git is already installed
            $gitVersion = git --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                $results.GitInstalled = $true
                $results.GitVersion = $gitVersion
                $results.InstallMethod = "Already installed"
                return $results
            }
        } catch {
            # Git not found, continue with installation
        }
        
        try {
            # Use Chocolatey to install Git (more reliable than winget on Server 2022)
            Write-Output "Checking for Chocolatey package manager..."
            
            # Install Chocolatey if not present
            try {
                choco --version 2>$null | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Output "Installing Chocolatey package manager..."
                    Set-ExecutionPolicy Bypass -Scope Process -Force
                    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
                    
                    # Refresh environment variables
                    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
                    
                    Write-Output "Chocolatey installed successfully"
                }
            } catch {
                Write-Output "Chocolatey check/install failed, using direct download method"
                throw "Chocolatey unavailable"
            }
            
            # Install Git using Chocolatey
            Write-Output "Installing Git using Chocolatey..."
            choco install git -y --no-progress
            
            if ($LASTEXITCODE -eq 0) {
                # Refresh PATH environment variable
                $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
                
                # Test Git installation
                Start-Sleep -Seconds 5
                $gitVersion = git --version 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $results.GitInstalled = $true
                    $results.GitVersion = $gitVersion
                    $results.InstallMethod = "Chocolatey"
                    return $results
                }
            }
        } catch {
            $results.Error += "Chocolatey method failed: $($_.Exception.Message); "
        }
        
        try {
            # Fallback: Download and install Git manually from GitHub releases
            Write-Output "Fallback: Downloading Git installer from GitHub..."
            
            # Use a more recent stable version
            $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe"
            $gitInstaller = "$env:TEMP\Git-installer.exe"
            
            # Download Git installer with progress
            Write-Output "Downloading Git installer..."
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($gitUrl, $gitInstaller)
            
            if (Test-Path $gitInstaller) {
                Write-Output "Installing Git silently..."
                # Install Git silently with PATH addition
                $installArgs = @(
                    "/VERYSILENT",
                    "/NORESTART",
                    "/NOCANCEL",
                    "/SP-",
                    "/CLOSEAPPLICATIONS",
                    "/RESTARTAPPLICATIONS",
                    "/COMPONENTS=icons,ext\reg\shellhere,assoc,assoc_sh",
                    "/TASKS=addtopath"
                )
                
                $process = Start-Process -FilePath $gitInstaller -ArgumentList $installArgs -Wait -PassThru
                
                if ($process.ExitCode -eq 0) {
                    Write-Output "Git installation completed, refreshing environment..."
                    
                    # Refresh PATH from registry
                    $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
                    $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
                    $env:PATH = "$machinePath;$userPath"
                    
                    # Wait a bit for installation to complete
                    Start-Sleep -Seconds 10
                    
                    # Test installation with full path
                    $gitExe = "${env:ProgramFiles}\Git\bin\git.exe"
                    if (Test-Path $gitExe) {
                        $gitVersion = & $gitExe --version 2>$null
                        if ($gitVersion) {
                            $results.GitInstalled = $true
                            $results.GitVersion = $gitVersion
                            $results.InstallMethod = "Manual download"
                            
                            # Clean up installer
                            Remove-Item -Path $gitInstaller -Force -ErrorAction SilentlyContinue
                            return $results
                        }
                    }
                    
                    # Also test if git is now in PATH
                    $gitVersion = git --version 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        $results.GitInstalled = $true
                        $results.GitVersion = $gitVersion
                        $results.InstallMethod = "Manual download"
                        
                        # Clean up installer
                        Remove-Item -Path $gitInstaller -Force -ErrorAction SilentlyContinue
                        return $results
                    }
                } else {
                    $results.Error += "Git installer failed with exit code: $($process.ExitCode); "
                }
                
                # Clean up installer even if failed
                Remove-Item -Path $gitInstaller -Force -ErrorAction SilentlyContinue
            } else {
                $results.Error += "Failed to download Git installer; "
            }
            
        } catch {
            $results.Error += "Manual install failed: $($_.Exception.Message)"
        }
        
        return $results
    }
    
    if ($gitInstallResult.GitInstalled) {
        Write-StepResult "Git Installation" $true "$($gitInstallResult.InstallMethod) - $($gitInstallResult.GitVersion)"
    } else {
        Write-StepResult "Git Installation" $false "" $gitInstallResult.Error
        return $false
    }
    
    return $true
}

function Clone-ApiRepository {
    param([object]$Session, [string]$RepoURL)
    
    Write-Host "`n📥 Cloning API Repository..." -ForegroundColor Cyan
    
    $cloneResult = Invoke-Command -Session $Session -ArgumentList $RepoURL -ScriptBlock {
        param($RepoURL)
        
        $results = @{
            Cloned = $false
            RepoPath = ""
            Error = ""
        }
        
        try {
            # Set working directory
            $workingDir = "C:\Users\Administrator\Documents"
            New-Item -Path $workingDir -ItemType Directory -Force | Out-Null
            Set-Location -Path $workingDir
            
            # Extract repository name from URL
            $repoNameWithExt = Split-Path -Leaf $RepoURL
            if ($repoNameWithExt -like "*.git") {
                $repoName = $repoNameWithExt.Substring(0, $repoNameWithExt.Length - 4)
            } else {
                $repoName = $repoNameWithExt
            }
            $repoPath = Join-Path $workingDir $repoName
            
            # Remove existing directory if it exists
            if (Test-Path $repoPath) {
                Write-Output "Removing existing repository directory..."
                Remove-Item -Path $repoPath -Recurse -Force
            }
            
            # Clone the repository
            Write-Output "Cloning repository: $RepoURL"
            Write-Output "Target directory: $repoPath"
            
            # Set Git to use full path and add to PATH if needed
            $gitExe = "${env:ProgramFiles}\Git\bin\git.exe"
            if (Test-Path $gitExe) {
                & $gitExe clone $RepoURL 2>&1 | Write-Output
                $gitExitCode = $LASTEXITCODE
            } else {
                git clone $RepoURL 2>&1 | Write-Output
                $gitExitCode = $LASTEXITCODE
            }
            
            if ($gitExitCode -eq 0) {
                if (Test-Path $repoPath) {
                    $results.Cloned = $true
                    $results.RepoPath = $repoPath
                    
                    # Get repository information
                    Set-Location -Path $repoPath
                    $gitBranch = "main"  # Default assumption
                    try {
                        if (Test-Path $gitExe) {
                            $gitBranch = & $gitExe branch --show-current 2>$null
                        } else {
                            $gitBranch = git branch --show-current 2>$null
                        }
                    } catch {
                        Write-Output "Could not determine git branch, using default"
                    }
                    
                    Write-Output "Repository cloned successfully to: $repoPath"
                    Write-Output "Current branch: $gitBranch"
                    
                    # List contents for verification
                    $contents = Get-ChildItem -Path $repoPath -Name
                    Write-Output "Repository contents: $($contents -join ', ')"
                    
                } else {
                    $results.Error = "Repository directory not found after clone: $repoPath"
                }
            } else {
                $results.Error = "Git clone command failed with exit code: $gitExitCode"
            }
            
        } catch {
            $results.Error = $_.Exception.Message
        }
        
        return $results
    }
    
    if ($cloneResult.Cloned) {
        Write-StepResult "Repository Clone" $true "Cloned to: $($cloneResult.RepoPath)"
        return $cloneResult.RepoPath
    } else {
        Write-StepResult "Repository Clone" $false "" $cloneResult.Error
        return $null
    }
}

function Install-ApiEnvironment {
    param([object]$Session, [string]$RepoPath)
    
    Write-Host "`n🚀 Installing Nutanix v4 API Environment..." -ForegroundColor Cyan
    
    $installResult = Invoke-Command -Session $Session -ArgumentList $RepoPath.Trim() -ScriptBlock {
        param($RepoPath)
        
        $results = @{
            Success = $false
            ScriptPath = ""
            Output = ""
            Error = ""
        }
        
        try {
            # Validate and navigate to repository
            if ([string]::IsNullOrWhiteSpace($RepoPath)) {
                $results.Error = "Repository path is null or empty"
                return $results
            }
            
            $cleanRepoPath = $RepoPath.Trim()
            if (-not (Test-Path $cleanRepoPath)) {
                $results.Error = "Repository path does not exist: $cleanRepoPath"
                return $results
            }
            
            Set-Location -Path $cleanRepoPath
            Write-Output "Changed to repository directory: $cleanRepoPath"
            
            # Check if the installation script exists
            $scriptPath = Join-Path $cleanRepoPath "experimental\Install-NtnxV4ApiEnvironment.ps1"
            
            if (Test-Path $scriptPath) {
                $results.ScriptPath = $scriptPath
                Write-Output "Found installation script: $scriptPath"
                
                # Execute the installation script
                Write-Output "Executing Nutanix v4 API environment installation..."
                
                # Set execution policy temporarily if needed
                $currentPolicy = Get-ExecutionPolicy -Scope Process
                Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
                
                try {
                    # Run the installation script and capture output
                    $installOutput = & $scriptPath 2>&1
                    $results.Output = $installOutput -join "`n"
                    
                    if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
                        $results.Success = $true
                        Write-Output "Installation completed successfully!"
                    } else {
                        $results.Error = "Installation script failed with exit code: $LASTEXITCODE"
                    }
                } catch {
                    $results.Error = "Script execution failed: $($_.Exception.Message)"
                } finally {
                    # Restore execution policy
                    Set-ExecutionPolicy -ExecutionPolicy $currentPolicy -Scope Process -Force
                }
                
            } else {
                # List available files for debugging
                $experimentalDir = Join-Path $cleanRepoPath "experimental"
                if (Test-Path $experimentalDir) {
                    $availableFiles = Get-ChildItem -Path $experimentalDir -Name "*.ps1" -ErrorAction SilentlyContinue
                    if ($availableFiles) {
                        $results.Error = "Installation script not found at: $scriptPath. Available scripts in experimental: $($availableFiles -join ', ')"
                    } else {
                        $results.Error = "No PowerShell scripts found in experimental directory: $experimentalDir"
                    }
                } else {
                    $results.Error = "Experimental directory not found: $experimentalDir"
                }
                
                # Also check for any install scripts in the repository
                $allInstallScripts = Get-ChildItem -Path $cleanRepoPath -Recurse -Name "*install*.ps1" -ErrorAction SilentlyContinue
                if ($allInstallScripts) {
                    $results.Error += ". Other install scripts found: $($allInstallScripts -join ', ')"
                }
            }
            
        } catch {
            $results.Error = $_.Exception.Message
        }
        
        return $results
    }
    
    if ($installResult.Success) {
        Write-StepResult "API Environment Installation" $true "Script executed: $($installResult.ScriptPath)"
        Write-Host "`n📋 Installation Output:" -ForegroundColor Cyan
        Write-Host $installResult.Output -ForegroundColor Gray
    } else {
        Write-StepResult "API Environment Installation" $false "" $installResult.Error
        if ($installResult.Output) {
            Write-Host "`n📋 Script Output:" -ForegroundColor Yellow
            Write-Host $installResult.Output -ForegroundColor Gray
        }
        return $false
    }
    
    return $true
}

# Main execution
Write-PhaseHeader "PHASE 2: NUTANIX V4 API DEVELOPMENT ENVIRONMENT SETUP"
Write-Host "Target VM: $VMIPAddress" -ForegroundColor White
Write-Host "Repository: $RepositoryURL" -ForegroundColor White
Write-Host "Connection: $(if($UseHTTPS){'HTTPS (Port 5986)'}else{'HTTP (Port 5985)'})" -ForegroundColor White

# Get credentials if not provided
if (-not $VMCredential) {
    $VMCredential = Get-VMCredentials
    if (-not $VMCredential) {
        Write-Host "❌ Cannot proceed without VM credentials." -ForegroundColor Red
        exit 1
    }
}

# Test VM connectivity
$connectivityTest = Test-VMConnectivity -IPAddress $VMIPAddress -Credential $VMCredential -UseHTTPS:$UseHTTPS
if (-not $connectivityTest) {
    Write-Host "❌ Cannot connect to VM. Please check VM status and credentials." -ForegroundColor Red
    exit 1
}

# Create PowerShell session for all operations
try {
    Write-Host "`n🔗 Establishing PowerShell session..." -ForegroundColor Cyan
    
    $sessionOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck
    $sessionParams = @{
        ComputerName = $VMIPAddress
        Credential = $VMCredential
        SessionOption = $sessionOptions
        ErrorAction = "Stop"
    }
    
    if ($UseHTTPS) {
        $sessionParams.Port = 5986
        $sessionParams.UseSSL = $true
    } else {
        $sessionParams.Port = 5985
    }
    
    $session = New-PSSession @sessionParams
    Write-StepResult "PowerShell Session" $true "Connected to $VMIPAddress"
    
    # Execute Phase 2 installation steps
    $gitInstallSuccess = Install-GitOnVM -Session $session
    if (-not $gitInstallSuccess) {
        Write-Host "❌ Git installation failed. Cannot proceed with repository clone." -ForegroundColor Red
        Remove-PSSession -Session $session
        exit 1
    }
    
    $repoPath = Clone-ApiRepository -Session $session -RepoURL $RepositoryURL
    if (-not $repoPath) {
        Write-Host "❌ Repository clone failed. Cannot proceed with installation." -ForegroundColor Red
        Remove-PSSession -Session $session
        exit 1
    }
    
    $apiInstallSuccess = Install-ApiEnvironment -Session $session -RepoPath $repoPath
    if (-not $apiInstallSuccess) {
        Write-Host "❌ API environment installation failed." -ForegroundColor Red
        Remove-PSSession -Session $session
        exit 1
    }
    
    # Clean up session
    Remove-PSSession -Session $session
    
    Write-Host "`n" + ("=" * 80) -ForegroundColor Magenta
    Write-Host "🎉 PHASE 2 INSTALLATION COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "`nYour VM is now set up with:" -ForegroundColor Cyan
    Write-Host "  ✓ Git for version control" -ForegroundColor Green
    Write-Host "  ✓ Nutanix v4 API development environment" -ForegroundColor Green
    Write-Host "  ✓ Required PowerShell modules and tools" -ForegroundColor Green
    Write-Host "`nRepository location on VM: $repoPath" -ForegroundColor White
    Write-Host ("=" * 80) -ForegroundColor Magenta
    
} catch {
    Write-StepResult "PowerShell Session" $false "" $_.Exception.Message
    Write-Host "❌ Failed to establish PowerShell session to VM." -ForegroundColor Red
    exit 1
}
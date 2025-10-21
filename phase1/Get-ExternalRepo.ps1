<#
.SYNOPSIS
    Utility functions for managing external repositories

.DESCRIPTION
    Provides functions to clone, update, and manage external repositories
    used in the auto-windows deployment process.

.NOTES
    Author: Hardev Sanghera
    Date: October 2025
#>

function Get-ExternalRepository {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoUrl,
        
        [Parameter(Mandatory = $true)]
        [string]$LocalPath,
        
        [Parameter(Mandatory = $false)]
        [string]$Branch = "main",
        
        [Parameter(Mandatory = $false)]
        [switch]$ForceClone
    )
    
    Write-Host "Managing repository: $RepoUrl" -ForegroundColor Cyan
    
    try {
        # Create parent directory if it doesn't exist
        $parentDir = Split-Path $LocalPath -Parent
        if (!(Test-Path $parentDir)) {
            New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
            Write-Host "Created directory: $parentDir" -ForegroundColor Green
        }
        
        # Check if repository already exists
        if (Test-Path $LocalPath) {
            if ($ForceClone) {
                Write-Host "Force clone requested, removing existing directory..." -ForegroundColor Yellow
                Remove-Item $LocalPath -Recurse -Force
            }
            else {
                # Try to update existing repository
                Write-Host "Repository exists, attempting to update..." -ForegroundColor Yellow
                Push-Location $LocalPath
                
                try {
                    # Check if it's a git repository
                    git status 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        # Pull latest changes
                        Write-Host "Pulling latest changes from $Branch branch..." -ForegroundColor Cyan
                        git checkout $Branch 2>&1 | Out-Null
                        git pull origin $Branch 2>&1 | Out-Null
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "Repository updated successfully" -ForegroundColor Green
                            return $true
                        }
                        else {
                            Write-Host "Failed to update repository, will re-clone" -ForegroundColor Yellow
                            Pop-Location
                            Remove-Item $LocalPath -Recurse -Force
                        }
                    }
                    else {
                        Write-Host "Directory exists but is not a git repository, removing..." -ForegroundColor Yellow
                        Pop-Location
                        Remove-Item $LocalPath -Recurse -Force
                    }
                }
                catch {
                    Write-Host "Error updating repository: $($_.Exception.Message)" -ForegroundColor Yellow
                    Pop-Location
                    Remove-Item $LocalPath -Recurse -Force -ErrorAction SilentlyContinue
                }
                finally {
                    if (Get-Location -eq $LocalPath) {
                        Pop-Location
                    }
                }
            }
        }
        
        # Clone the repository if it doesn't exist or was removed
        if (!(Test-Path $LocalPath)) {
            Write-Host "Cloning repository from: $RepoUrl" -ForegroundColor Cyan
            Write-Host "Clone destination: $LocalPath" -ForegroundColor Cyan
            
            # Execute git clone
            $gitArgs = @("clone")
            if ($Branch -and $Branch -ne "main") {
                $gitArgs += @("-b", $Branch)
            }
            $gitArgs += @($RepoUrl, $LocalPath)
            
            $process = Start-Process -FilePath "git" -ArgumentList $gitArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\git_clone_output.txt" -RedirectStandardError "$env:TEMP\git_clone_error.txt"
            
            # Check results
            if ($process.ExitCode -eq 0) {
                Write-Host "Repository cloned successfully!" -ForegroundColor Green
                
                # Verify clone
                if (Test-Path $LocalPath -and (Get-ChildItem $LocalPath).Count -gt 0) {
                    Write-Host "Clone verification passed" -ForegroundColor Green
                    return $true
                }
                else {
                    Write-Host "Clone verification failed - directory empty" -ForegroundColor Red
                    return $false
                }
            }
            else {
                # Read error output
                $errorOutput = ""
                if (Test-Path "$env:TEMP\git_clone_error.txt") {
                    $errorOutput = Get-Content "$env:TEMP\git_clone_error.txt" -Raw
                }
                
                Write-Host "Git clone failed with exit code: $($process.ExitCode)" -ForegroundColor Red
                if ($errorOutput) {
                    Write-Host "Error details: $errorOutput" -ForegroundColor Red
                }
                
                return $false
            }
        }
        
        return $true
    }
    catch {
        Write-Host "Exception during repository operations: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    finally {
        # Cleanup temporary files
        Remove-Item "$env:TEMP\git_clone_output.txt" -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:TEMP\git_clone_error.txt" -Force -ErrorAction SilentlyContinue
    }
}

function Test-GitAvailability {
    try {
        git --version | Out-Null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Install-GitIfMissing {
    if (!(Test-GitAvailability)) {
        Write-Host "Git is not available. Attempting installation..." -ForegroundColor Yellow
        
        # Try to install via winget if available
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            try {
                Write-Host "Installing Git via winget..." -ForegroundColor Cyan
                winget install --id Git.Git --source winget --silent --accept-package-agreements --accept-source-agreements
                
                # Refresh PATH
                $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
                
                # Test again
                if (Test-GitAvailability) {
                    Write-Host "Git installed successfully!" -ForegroundColor Green
                    return $true
                }
            }
            catch {
                Write-Host "Winget installation failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        # Fallback: Download and install manually
        try {
            Write-Host "Downloading Git for Windows..." -ForegroundColor Cyan
            $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe"
            $gitInstaller = "$env:TEMP\Git-installer.exe"
            
            Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing
            
            Write-Host "Installing Git for Windows..." -ForegroundColor Cyan
            Start-Process -FilePath $gitInstaller -ArgumentList "/SILENT" -Wait
            
            # Refresh PATH
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
            
            # Test installation
            if (Test-GitAvailability) {
                Write-Host "Git installed successfully!" -ForegroundColor Green
                return $true
            }
            else {
                Write-Host "Git installation verification failed" -ForegroundColor Red
                return $false
            }
        }
        catch {
            Write-Host "Manual Git installation failed: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
        finally {
            # Cleanup installer
            Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue
        }
    }
    else {
        Write-Host "Git is already available" -ForegroundColor Green
        return $true
    }
}

function Get-RepositoryInfo {
    param([string]$LocalPath)
    
    if (!(Test-Path $LocalPath)) {
        return $null
    }
    
    try {
        Push-Location $LocalPath
        
        $info = @{
            Path = $LocalPath
            Exists = $true
            IsGitRepo = $false
            Branch = $null
            LastCommit = $null
            RemoteUrl = $null
        }
        
        # Check if it's a git repository
        git status 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $info.IsGitRepo = $true
            
            # Get current branch
            $branch = git rev-parse --abbrev-ref HEAD 2>&1
            if ($LASTEXITCODE -eq 0) {
                $info.Branch = $branch
            }
            
            # Get last commit
            $commit = git log -1 --pretty=format:"%h %s" 2>&1
            if ($LASTEXITCODE -eq 0) {
                $info.LastCommit = $commit
            }
            
            # Get remote URL
            $remote = git remote get-url origin 2>&1
            if ($LASTEXITCODE -eq 0) {
                $info.RemoteUrl = $remote
            }
        }
        
        return $info
    }
    catch {
        return $null
    }
    finally {
        Pop-Location
    }
}

# Export functions
Export-ModuleMember -Function Get-ExternalRepository, Test-GitAvailability, Install-GitIfMissing, Get-RepositoryInfo
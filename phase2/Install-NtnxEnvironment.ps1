<#
.SYNOPSIS
    Nutanix v4 API Environment Installation Wrapper

.DESCRIPTION
    Provides wrapper functions for executing and managing the 
    Install-NtnxV4ApiEnvironment.ps1 script from the ntnx-v4api-cats repository.
    Includes utilities for parameter configuration and execution monitoring.

.NOTES
    Author: Hardev Sanghera
    Date: October 2025
#>

function Invoke-NutanixEnvironmentInstall {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        
        [Parameter(Mandatory = $false)]
        [string]$RepositoryPath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipGitClone,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force,
        
        [Parameter(Mandatory = $false)]
        [switch]$NonInteractive
    )
    
    Write-Host "=== NUTANIX V4 API ENVIRONMENT INSTALLATION ===" -ForegroundColor Cyan
    
    try {
        # Verify the installation script exists
        if (!(Test-Path $ScriptPath)) {
            throw "Installation script not found: $ScriptPath"
        }
        
        Write-Host "Installation script found: $ScriptPath" -ForegroundColor Green
        
        # Build parameter hashtable
        $params = @{}
        
        if ($RepositoryPath) {
            $params['RepositoryPath'] = $RepositoryPath
        }
        
        if ($SkipGitClone) {
            $params['SkipGitClone'] = $true
        }
        
        if ($Force) {
            $params['Force'] = $true
        }
        
        # Display installation parameters
        Write-Host "Installation Parameters:" -ForegroundColor Yellow
        if ($params.Count -gt 0) {
            foreach ($key in $params.Keys) {
                Write-Host "  $key`: $($params[$key])" -ForegroundColor Gray
            }
        }
        else {
            Write-Host "  Using default parameters" -ForegroundColor Gray
        }
        
        Write-Host ""
        
        # Confirm installation in interactive mode
        if (!$NonInteractive) {
            $confirm = Read-Host "Proceed with Nutanix v4 API environment installation? (Y/n)"
            if ($confirm -match "^[Nn]") {
                Write-Host "Installation cancelled by user" -ForegroundColor Yellow
                return @{ Success = $false; Cancelled = $true }
            }
        }
        
        # Execute the installation script
        Write-Host "Starting Nutanix v4 API environment installation..." -ForegroundColor Cyan
        Write-Host "This may take several minutes..." -ForegroundColor Gray
        
        $startTime = Get-Date
        
        # Execute with parameters
        if ($params.Count -gt 0) {
            & $ScriptPath @params
        }
        else {
            & $ScriptPath
        }
        
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        Write-Host ""
        Write-Host "Installation script execution completed" -ForegroundColor Green
        Write-Host "Duration: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
        
        return @{
            Success = $true
            StartTime = $startTime
            EndTime = $endTime
            Duration = $duration
        }
    }
    catch {
        Write-Host "Installation script execution failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Test-InstallationScript {
    param([string]$ScriptPath)
    
    Write-Host "Validating installation script..." -ForegroundColor Cyan
    
    try {
        if (!(Test-Path $ScriptPath)) {
            return @{ Valid = $false; Reason = "Script file not found" }
        }
        
        # Check file size (should be substantial)
        $fileInfo = Get-Item $ScriptPath
        if ($fileInfo.Length -lt 10KB) {
            return @{ Valid = $false; Reason = "Script file appears too small (less than 10KB)" }
        }
        
        # Check for PowerShell syntax
        $content = Get-Content $ScriptPath -Raw
        if ($content -notmatch "#.*PowerShell|param\s*\(") {
            return @{ Valid = $false; Reason = "File does not appear to be a PowerShell script" }
        }
        
        # Check for expected functions/content
        $expectedContent = @(
            "Install-NtnxV4ApiEnvironment",
            "PowerShell 7",
            "Python 3.13",
            "Visual Studio Code"
        )
        
        $foundContent = 0
        foreach ($expected in $expectedContent) {
            if ($content -match [regex]::Escape($expected)) {
                $foundContent++
            }
        }
        
        if ($foundContent -lt 2) {
            return @{ Valid = $false; Reason = "Script content validation failed" }
        }
        
        Write-Host "Installation script validation passed" -ForegroundColor Green
        return @{
            Valid = $true
            Size = $fileInfo.Length
            LastModified = $fileInfo.LastWriteTime
        }
    }
    catch {
        return @{ Valid = $false; Reason = "Validation error: $($_.Exception.Message)" }
    }
}

function Get-ComponentVersions {
    <#
    .SYNOPSIS
    Checks versions of components that should be installed
    #>
    
    Write-Host "Checking installed component versions..." -ForegroundColor Cyan
    
    $versions = @{}
    
    # PowerShell 7
    try {
        if (Get-Command pwsh -ErrorAction SilentlyContinue) {
            $pwshVersion = pwsh --version 2>&1
            $versions['PowerShell7'] = $pwshVersion.ToString().Trim()
        }
        else {
            $versions['PowerShell7'] = "Not installed"
        }
    }
    catch {
        $versions['PowerShell7'] = "Check failed"
    }
    
    # Python
    try {
        if (Get-Command python -ErrorAction SilentlyContinue) {
            $pythonVersion = python --version 2>&1
            $versions['Python'] = $pythonVersion.ToString().Trim()
        }
        else {
            $versions['Python'] = "Not installed"
        }
    }
    catch {
        $versions['Python'] = "Check failed"
    }
    
    # Visual Studio Code
    try {
        if (Get-Command code -ErrorAction SilentlyContinue) {
            $codeVersion = code --version 2>&1 | Select-Object -First 1
            $versions['VSCode'] = $codeVersion.ToString().Trim()
        }
        else {
            $versions['VSCode'] = "Not installed"
        }
    }
    catch {
        $versions['VSCode'] = "Check failed"
    }
    
    # Git
    try {
        if (Get-Command git -ErrorAction SilentlyContinue) {
            $gitVersion = git --version 2>&1
            $versions['Git'] = $gitVersion.ToString().Trim()
        }
        else {
            $versions['Git'] = "Not installed"
        }
    }
    catch {
        $versions['Git'] = "Check failed"
    }
    
    # Display versions
    Write-Host "Component Versions:" -ForegroundColor Yellow
    foreach ($component in $versions.Keys) {
        $version = $versions[$component]
        $color = if ($version -eq "Not installed" -or $version -eq "Check failed") { "Red" } else { "Green" }
        Write-Host "  $component`: $version" -ForegroundColor $color
    }
    
    return $versions
}

function Test-NutanixAPIEnvironment {
    param([string]$RepositoryPath)
    
    Write-Host "Testing Nutanix API environment..." -ForegroundColor Cyan
    
    $testResults = @{
        RepositoryExists = $false
        RequiredFiles = @()
        MissingFiles = @()
        PythonEnvironment = $false
        ConfigFiles = @()
        OverallStatus = $false
    }
    
    try {
        # Check repository path
        if ($RepositoryPath -and (Test-Path $RepositoryPath)) {
            $testResults.RepositoryExists = $true
            Write-Host "✓ Repository found: $RepositoryPath" -ForegroundColor Green
            
            Push-Location $RepositoryPath
            
            # Check for required files
            $requiredFiles = @(
                "list_vms.ps1",
                "list_categories.ps1", 
                "build_workbook.ps1",
                "update_categories_for_vm.py",
                "files\vars.txt",
                "files\requirements.txt"
            )
            
            foreach ($file in $requiredFiles) {
                if (Test-Path $file) {
                    $testResults.RequiredFiles += $file
                }
                else {
                    $testResults.MissingFiles += $file
                }
            }
            
            Write-Host "✓ Required files found: $($testResults.RequiredFiles.Count)/$($requiredFiles.Count)" -ForegroundColor Green
            
            if ($testResults.MissingFiles.Count -gt 0) {
                Write-Host "⚠ Missing files:" -ForegroundColor Yellow
                foreach ($file in $testResults.MissingFiles) {
                    Write-Host "    $file" -ForegroundColor Red
                }
            }
            
            # Check Python virtual environment
            if (Test-Path ".venv") {
                $testResults.PythonEnvironment = $true
                Write-Host "✓ Python virtual environment found" -ForegroundColor Green
            }
            else {
                Write-Host "⚠ Python virtual environment not found" -ForegroundColor Yellow
            }
            
            # Check configuration files
            $configDir = "files"
            if (Test-Path $configDir) {
                $configFiles = Get-ChildItem $configDir -Filter "*.txt" | Select-Object -ExpandProperty Name
                $testResults.ConfigFiles = $configFiles
                Write-Host "✓ Configuration directory found with $($configFiles.Count) files" -ForegroundColor Green
            }
        }
        else {
            Write-Host "✗ Repository not found: $RepositoryPath" -ForegroundColor Red
        }
        
        # Overall status
        $testResults.OverallStatus = $testResults.RepositoryExists -and 
                                   ($testResults.RequiredFiles.Count -gt ($testResults.RequiredFiles.Count + $testResults.MissingFiles.Count) / 2)
        
        $status = if ($testResults.OverallStatus) { "PASS" } else { "FAIL" }
        $color = if ($testResults.OverallStatus) { "Green" } else { "Red" }
        Write-Host "Overall Environment Status: $status" -ForegroundColor $color
        
        return $testResults
    }
    catch {
        Write-Host "Environment test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $testResults
    }
    finally {
        if (Get-Location -ne $PWD) {
            Pop-Location
        }
    }
}

function Start-PostInstallationTasks {
    param(
        [string]$RepositoryPath,
        [object]$Config
    )
    
    Write-Host "=== POST-INSTALLATION TASKS ===" -ForegroundColor Cyan
    
    try {
        # Open VS Code if configured and available
        if ($Config.postInstall.openVSCode -and (Get-Command code -ErrorAction SilentlyContinue)) {
            if ($RepositoryPath -and (Test-Path $RepositoryPath)) {
                Write-Host "Opening Visual Studio Code at repository location..." -ForegroundColor Cyan
                Start-Process code -ArgumentList "`"$RepositoryPath`"" -NoNewWindow
                Write-Host "✓ VS Code opened" -ForegroundColor Green
            }
        }
        
        # Display next steps
        Write-Host ""
        Write-Host "=== NEXT STEPS ===" -ForegroundColor Yellow
        Write-Host "1. Configure your Nutanix Prism Central details in files\vars.txt" -ForegroundColor White
        Write-Host "2. Navigate to the repository: cd `"$RepositoryPath`"" -ForegroundColor White
        Write-Host "3. Activate Python environment: .\.venv\Scripts\Activate.ps1" -ForegroundColor White
        Write-Host "4. Run the API workflow scripts:" -ForegroundColor White
        Write-Host "   - .\list_vms.ps1" -ForegroundColor Gray
        Write-Host "   - .\list_categories.ps1" -ForegroundColor Gray
        Write-Host "   - .\build_workbook.ps1" -ForegroundColor Gray
        Write-Host "5. Use the generated Excel files to manage VM categories" -ForegroundColor White
        Write-Host ""
        Write-Host "Documentation: https://github.com/hardevsanghera/ntnx-v4api-cats" -ForegroundColor Cyan
        
        return $true
    }
    catch {
        Write-Host "Post-installation tasks failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Export functions
Export-ModuleMember -Function Invoke-NutanixEnvironmentInstall, Test-InstallationScript, Get-ComponentVersions, Test-NutanixAPIEnvironment, Start-PostInstallationTasks
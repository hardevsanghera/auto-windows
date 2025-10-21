<#
.SYNOPSIS
    Configuration Setup and Validation Helper

.DESCRIPTION
    Helps users set up and validate Auto-Windows configurations before deployment.
    Provides interactive setup, validation, and testing capabilities.

.PARAMETER Action
    Action to perform: Setup, Validate, Test, or Reset

.PARAMETER ConfigType
    Configuration type: dev, prod, full, minimal, or custom

.PARAMETER Interactive
    Run in interactive mode for guided setup

.EXAMPLE
    .\Setup-Configuration.ps1 -Action Setup -Interactive
    
.EXAMPLE
    .\Setup-Configuration.ps1 -Action Validate -ConfigType dev

.NOTES
    Author: Hardev Sanghera
    Date: October 2025
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Setup", "Validate", "Test", "Reset")]
    [string]$Action = "Setup",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("dev", "prod", "full", "minimal", "custom")]
    [string]$ConfigType = "dev",
    
    [Parameter(Mandatory = $false)]
    [switch]$Interactive
)

function Write-Header {
    param([string]$Title)
    
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""
}

function Read-SecureInput {
    param(
        [string]$Prompt,
        [string]$Default = "",
        [switch]$IsPassword,
        [switch]$IsOptional
    )
    
    $promptText = $Prompt
    if ($Default) {
        $promptText += " (default: $Default)"
    }
    if ($IsOptional) {
        $promptText += " [Optional]"
    }
    $promptText += ": "
    
    if ($IsPassword) {
        $secure = Read-Host $promptText -AsSecureString
        return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
    }
    else {
        $input = Read-Host $promptText
        if ($input) { 
            return $input 
        } else { 
            return $Default 
        }
    }
}

function Start-InteractiveSetup {
    Write-Header "Auto-Windows Interactive Configuration Setup"
    
    Write-Host "This wizard will help you configure Auto-Windows for your environment." -ForegroundColor Green
    Write-Host ""
    
    # Choose configuration template
    Write-Host "Available configuration templates:" -ForegroundColor Yellow
    Write-Host "1. Development (dev) - Basic development environment setup" -ForegroundColor White
    Write-Host "2. Production (prod) - Production environment with security considerations" -ForegroundColor White  
    Write-Host "3. Full (full) - Complete installation with all components" -ForegroundColor White
    Write-Host "4. Minimal (minimal) - Minimal installation for basic API access" -ForegroundColor White
    Write-Host "5. Custom - Start with empty template" -ForegroundColor White
    Write-Host ""
    
    do {
        $choice = Read-Host "Select a template (1-5)"
    } while ($choice -notmatch "^[1-5]$")
    
    $templateMap = @{
        "1" = "dev"
        "2" = "prod" 
        "3" = "full"
        "4" = "minimal"
        "5" = "custom"
    }
    
    $selectedTemplate = $templateMap[$choice]
    Write-Host "Selected template: $selectedTemplate" -ForegroundColor Green
    
    # Load base configuration
    $config = Get-BaseConfiguration -Type $selectedTemplate
    
    # Phase 1 Configuration
    Write-Header "Phase 1: VM Deployment Configuration"
    
    $config.prismCentral.ip = Read-SecureInput -Prompt "Prism Central IP address" -Default $config.prismCentral.ip
    $config.prismCentral.username = Read-SecureInput -Prompt "Prism Central username" -Default $config.prismCentral.username
    
    # Only prompt for password if not in non-interactive mode
    Write-Host "Note: Passwords will not be stored in configuration files for security." -ForegroundColor Yellow
    Write-Host "You will be prompted for passwords during deployment." -ForegroundColor Yellow
    
    $config.vmConfiguration.namePrefix = Read-SecureInput -Prompt "VM name prefix" -Default $config.vmConfiguration.namePrefix
    
    # Domain configuration
    $joinDomain = Read-Host "Join VMs to domain? (y/N)"
    if ($joinDomain -match "^[Yy]") {
        $config.vmConfiguration.domain.join = $true
        $config.vmConfiguration.domain.name = Read-SecureInput -Prompt "Domain name"
        $config.vmConfiguration.domain.username = Read-SecureInput -Prompt "Domain admin username"
    }
    
    # Phase 2 Configuration (basic setup)
    Write-Header "Phase 2: API Environment Configuration"
    
    $installPath = Read-SecureInput -Prompt "API environment install path" -Default "C:\Dev\ntnx-v4api-cats"
    
    # Component selection
    Write-Host "Select components to install:" -ForegroundColor Yellow
    $installPS7 = (Read-Host "Install PowerShell 7? (Y/n)") -notmatch "^[Nn]"
    $installPython = (Read-Host "Install Python 3.13+? (Y/n)") -notmatch "^[Nn]"
    $installVSCode = (Read-Host "Install Visual Studio Code? (Y/n)") -notmatch "^[Nn]"
    $installGit = (Read-Host "Install Git for Windows? (Y/n)") -notmatch "^[Nn]"
    
    # Save configuration
    Write-Header "Saving Configuration"
    
    $configName = Read-SecureInput -Prompt "Configuration name" -Default $selectedTemplate
    Save-Configuration -Config $config -InstallPath $installPath -Components @{
        PowerShell7 = $installPS7
        Python = $installPython
        VSCode = $installVSCode
        Git = $installGit
    } -Type $selectedTemplate
    
    Write-Host "Configuration saved successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Review the configuration files in the config\ directory" -ForegroundColor White
    Write-Host "2. Run: .\Deploy-AutoWindows.ps1" -ForegroundColor White
    Write-Host ""
}

function Get-BaseConfiguration {
    param([string]$Type)
    
    $defaultConfig = @{
        prismCentral = @{
            ip = ""
            username = ""
            password = ""
            port = 9440
        }
        vmConfiguration = @{
            namePrefix = "WIN-AUTO-"
            adminPassword = ""
            domain = @{
                join = $false
                name = ""
                username = ""
                password = ""
            }
        }
        deployment = @{
            mode = "interactive"
            autoSelectResources = $false
            selectedResources = @{
                cluster = ""
                subnet = ""
                image = ""
                sysprepFile = ""
            }
        }
        monitoring = @{
            checkInterval = 30
            maxWaitTime = 1800
            enableNotifications = $false
        }
    }
    
    # Try to load template if it exists
    try {
        switch ($Type) {
            "dev" {
                if (Test-Path "config\deployment-config.dev.json") {
                    return Get-Content "config\deployment-config.dev.json" -Raw | ConvertFrom-Json
                }
            }
            "prod" {
                if (Test-Path "config\deployment-config.prod.json") {
                    return Get-Content "config\deployment-config.prod.json" -Raw | ConvertFrom-Json
                }
            }
            "custom" {
                if (Test-Path "config\deployment-config.json") {
                    return Get-Content "config\deployment-config.json" -Raw | ConvertFrom-Json
                }
            }
        }
    }
    catch {
        Write-Host "Could not load template, using defaults" -ForegroundColor Yellow
    }
    
    return [PSCustomObject]$defaultConfig
}

function Save-Configuration {
    param(
        [object]$Config,
        [string]$InstallPath,
        [hashtable]$Components,
        [string]$Type
    )
    
    $deploymentPath = "config\deployment-config.json"
    $environmentPath = "config\environment-config.json"
    
    # Ensure config directory exists
    if (!(Test-Path "config")) {
        New-Item -Path "config" -ItemType Directory -Force | Out-Null
    }
    
    # Save deployment configuration
    $Config | ConvertTo-Json -Depth 10 | Set-Content $deploymentPath
    
    # Create environment configuration
    $envConfig = @{
        environment = @{
            installPath = $InstallPath
            skipGitClone = $false
            forceReinstall = $false
        }
        components = @{
            powershell7 = @{
                install = $Components.PowerShell7
                required = $true
            }
            python = @{
                install = $Components.Python
                version = "3.13+"
                required = $true
            }
            vscode = @{
                install = $Components.VSCode
                configureWorkspace = $true
                extensions = @(
                    "ms-python.python",
                    "ms-vscode.powershell",
                    "redhat.vscode-yaml",
                    "donjayamanne.githistory",
                    "eamodio.gitlens"
                )
            }
            git = @{
                install = $Components.Git
                required = $true
            }
        }
        postInstall = @{
            openVSCode = $true
            activateEnvironment = $true
            runSampleScript = $false
        }
        validation = @{
            testConnections = $true
            verifyInstallations = $true
            generateReport = $true
        }
    }
    
    $envConfig | ConvertTo-Json -Depth 10 | Set-Content $environmentPath
    
    Write-Host "Configuration files created:" -ForegroundColor Green
    Write-Host "  $deploymentPath" -ForegroundColor Gray
    Write-Host "  $environmentPath" -ForegroundColor Gray
}

function Test-Configuration {
    param([string]$Type)
    
    Write-Header "Configuration Validation"
    
    $issues = @()
    
    # Test deployment config
    $deploymentPath = "config\deployment-config.json"
    if (Test-Path $deploymentPath) {
        try {
            $deploymentConfig = Get-Content $deploymentPath -Raw | ConvertFrom-Json
            
            # Validate required fields
            if (!$deploymentConfig.prismCentral.ip) {
                $issues += "Prism Central IP is required"
            }
            if (!$deploymentConfig.prismCentral.username) {
                $issues += "Prism Central username is required"  
            }
            
            # Test connectivity if IP is provided
            if ($deploymentConfig.prismCentral.ip) {
                Write-Host "Testing Prism Central connectivity..." -ForegroundColor Cyan
                try {
                    Test-Connection -ComputerName $deploymentConfig.prismCentral.ip -Count 1 -ErrorAction Stop | Out-Null
                    Write-Host "✓ Prism Central is reachable" -ForegroundColor Green
                }
                catch {
                    $issues += "Cannot reach Prism Central at $($deploymentConfig.prismCentral.ip)"
                }
            }
            
            Write-Host "✓ Deployment configuration is valid" -ForegroundColor Green
        }
        catch {
            $issues += "Invalid deployment configuration: $($_.Exception.Message)"
        }
    }
    else {
        $issues += "Deployment configuration file not found: $deploymentPath"
    }
    
    # Test environment config
    $environmentPath = "config\environment-config.json"
    if (Test-Path $environmentPath) {
        try {
            $environmentConfig = Get-Content $environmentPath -Raw | ConvertFrom-Json
            
            # Validate install path
            if ($environmentConfig.environment.installPath) {
                $parentDir = Split-Path $environmentConfig.environment.installPath -Parent
                if (!(Test-Path $parentDir)) {
                    $issues += "Install path parent directory does not exist: $parentDir"
                }
            }
            
            Write-Host "✓ Environment configuration is valid" -ForegroundColor Green
        }
        catch {
            $issues += "Invalid environment configuration: $($_.Exception.Message)"
        }
    }
    else {
        $issues += "Environment configuration file not found: $environmentPath"
    }
    
    # Report results
    if ($issues.Count -eq 0) {
        Write-Host "✓ All configuration validations passed!" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "✗ Configuration validation failed:" -ForegroundColor Red
        foreach ($issue in $issues) {
            Write-Host "  - $issue" -ForegroundColor Red
        }
        return $false
    }
}

function Reset-Configuration {
    Write-Header "Reset Configuration"
    
    $confirm = Read-Host "This will reset all configurations to defaults. Continue? (y/N)"
    if ($confirm -notmatch "^[Yy]") {
        Write-Host "Reset cancelled" -ForegroundColor Yellow
        return
    }
    
    # Create config directory if it doesn't exist
    if (!(Test-Path "config")) {
        New-Item -Path "config" -ItemType Directory -Force | Out-Null
    }
    
    # Reset to defaults by copying templates if they exist, otherwise create basic configs
    if (Test-Path "config\deployment-config.dev.json") {
        Copy-Item "config\deployment-config.dev.json" "config\deployment-config.json" -Force
    }
    else {
        # Create basic deployment config
        $defaultConfig = Get-BaseConfiguration -Type "custom"
        $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content "config\deployment-config.json"
    }
    
    if (Test-Path "config\environment-config.full.json") {
        Copy-Item "config\environment-config.full.json" "config\environment-config.json" -Force
    }
    else {
        # Create basic environment config
        Save-Configuration -Config (Get-BaseConfiguration -Type "custom") -InstallPath "C:\Dev\ntnx-v4api-cats" -Components @{
            PowerShell7 = $true
            Python = $true
            VSCode = $true
            Git = $true
        } -Type "custom"
    }
    
    Write-Host "✓ Configuration reset to defaults" -ForegroundColor Green
}

# Main execution
try {
    switch ($Action) {
        "Setup" {
            if ($Interactive) {
                Start-InteractiveSetup
            }
            else {
                Write-Host "Use -Interactive for guided setup" -ForegroundColor Yellow
                Write-Host "Example: .\Setup-Configuration.ps1 -Action Setup -Interactive" -ForegroundColor Gray
                Write-Host "Or manually edit configuration files in the config\ directory" -ForegroundColor Gray
            }
        }
        "Validate" {
            Test-Configuration -Type $ConfigType
        }
        "Test" {
            Test-Configuration -Type $ConfigType
        }
        "Reset" {
            Reset-Configuration
        }
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
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
        return if ($input) { $input } else { $Default }
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
    $config.prismCentral.password = Read-SecureInput -Prompt "Prism Central password" -IsPassword
    
    $config.vmConfiguration.namePrefix = Read-SecureInput -Prompt "VM name prefix" -Default $config.vmConfiguration.namePrefix
    $config.vmConfiguration.adminPassword = Read-SecureInput -Prompt "VM Administrator password" -IsPassword
    
    # Domain configuration
    $joinDomain = Read-Host "Join VMs to domain? (y/N)"
    if ($joinDomain -match "^[Yy]") {
        $config.vmConfiguration.domain.join = $true
        $config.vmConfiguration.domain.name = Read-SecureInput -Prompt "Domain name"
        $config.vmConfiguration.domain.username = Read-SecureInput -Prompt "Domain admin username"
        $config.vmConfiguration.domain.password = Read-SecureInput -Prompt "Domain admin password" -IsPassword
    }
    
    # Phase 2 Configuration
    Write-Header "Phase 2: API Environment Configuration"
    
    $installPath = Read-SecureInput -Prompt "API environment install path" -Default "C:\Dev\ntnx-v4api-cats"
    $config.environment.installPath = $installPath
    
    # Component selection
    Write-Host "Select components to install:" -ForegroundColor Yellow
    $config.components.powershell7.install = (Read-Host "Install PowerShell 7? (Y/n)") -notmatch "^[Nn]"
    $config.components.python.install = (Read-Host "Install Python 3.13+? (Y/n)") -notmatch "^[Nn]"
    $config.components.vscode.install = (Read-Host "Install Visual Studio Code? (Y/n)") -notmatch "^[Nn]"
    $config.components.git.install = (Read-Host "Install Git for Windows? (Y/n)") -notmatch "^[Nn]"
    
    # Save configuration
    Write-Header "Saving Configuration"
    
    $configName = Read-SecureInput -Prompt "Configuration name" -Default $selectedTemplate
    Save-Configuration -Config $config -Name $configName -Type $selectedTemplate
    
    Write-Host "Configuration saved successfully!" -ForegroundColor Green
    Write-Host "You can now run: .\Deploy-AutoWindows.ps1" -ForegroundColor Cyan
}

function Get-BaseConfiguration {
    param([string]$Type)
    
    switch ($Type) {
        "dev" {
            return Get-Content "config\deployment-config.dev.json" -Raw | ConvertFrom-Json
        }
        "prod" {
            return Get-Content "config\deployment-config.prod.json" -Raw | ConvertFrom-Json  
        }
        "custom" {
            return Get-Content "config\deployment-config.json" -Raw | ConvertFrom-Json
        }
        default {
            return Get-Content "config\deployment-config.json" -Raw | ConvertFrom-Json
        }
    }
}

function Save-Configuration {
    param(
        [object]$Config,
        [string]$Name,
        [string]$Type
    )
    
    $deploymentPath = "config\deployment-config.json"
    $environmentPath = "config\environment-config.json"
    
    # Save deployment configuration
    $Config | ConvertTo-Json -Depth 10 | Set-Content $deploymentPath
    
    # Create environment configuration if needed
    if ($Type -eq "full") {
        Copy-Item "config\environment-config.full.json" $environmentPath -Force
    }
    elseif ($Type -eq "minimal") {
        Copy-Item "config\environment-config.minimal.json" $environmentPath -Force
    }
    else {
        # Use default environment config
        if (!(Test-Path $environmentPath)) {
            Copy-Item "config\environment-config.json" $environmentPath -Force
        }
    }
    
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
            
            # Test connectivity (if credentials provided)
            if ($deploymentConfig.prismCentral.ip -and $deploymentConfig.prismCentral.username -and $deploymentConfig.prismCentral.password) {
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
    
    # Reset to defaults
    Copy-Item "config\deployment-config.dev.json" "config\deployment-config.json" -Force
    Copy-Item "config\environment-config.json" "config\environment-config.json" -Force
    
    Write-Host "✓ Configuration reset to defaults" -ForegroundColor Green
}

# Main execution
switch ($Action) {
    "Setup" {
        if ($Interactive) {
            Start-InteractiveSetup
        }
        else {
            Write-Host "Use -Interactive for guided setup" -ForegroundColor Yellow
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
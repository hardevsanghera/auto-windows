# Auto-Windows: Usage Examples

This document provides practical examples for common Auto-Windows deployment scenarios.

## Basic Examples

### Example 1: Complete First-Time Setup

**Scenario**: New user wants to deploy a development VM and set up API environment.

```powershell
# Step 1: Clone the repository
git clone https://github.com/your-org/auto-windows.git
cd auto-windows

# Step 2: Interactive configuration setup
.\Setup-Configuration.ps1 -Action Setup -Interactive

# Follow prompts to configure:
# - Prism Central IP: 192.168.1.100
# - Username: admin  
# - Password: [secure password]
# - VM prefix: DEV-WIN-
# - Install components: All (Y/Y/Y/Y)

# Step 3: Run complete deployment
.\Deploy-AutoWindows.ps1

# Expected output:
# ===================================
#    AUTO-WINDOWS DEPLOYMENT
# ===================================
# 
# Starting Auto-Windows deployment process...
# Phase selection: All
# 
# ===================================
#    PHASE 1: Windows VM Deployment
# ===================================
# 
# Cloning VM deployment repository...
# Setting up Python environment...
# Starting VM deployment process...
# VM deployed successfully!
# VM UUID: 12345678-1234-5678-9abc-123456789def
# 
# ===================================
#    PHASE 2: Nutanix v4 API Environment Setup
# ===================================
# 
# Downloading installation script...
# Installing PowerShell 7...
# Installing Python 3.13+...
# Installing Visual Studio Code...
# Installing Git for Windows...
# Setting up API repository...
# 
# ===================================
#    EXECUTION SUMMARY
# ===================================
# 
# Phase 1 (VM Deployment): SUCCESS ✓
# Phase 2 (API Environment): SUCCESS ✓
# Overall Status: SUCCESS ✓
```

### Example 2: VM Deployment Only

**Scenario**: User only wants to deploy VMs without setting up the API environment.

```powershell
# Configure for VM deployment only
.\Setup-Configuration.ps1 -Action Setup -ConfigType dev -Interactive

# Run Phase 1 only
.\Deploy-AutoWindows.ps1 -Phase 1

# Expected result:
# - VM deployed to Nutanix cluster
# - No API environment setup
# - Logs in logs\phase1.log
```

### Example 3: API Environment Setup Only

**Scenario**: User has VMs already and just wants to set up the Nutanix API development environment.

```powershell
# Configure environment setup
.\Setup-Configuration.ps1 -Action Setup -ConfigType full -Interactive

# Run Phase 2 only
.\Deploy-AutoWindows.ps1 -Phase 2

# Expected result:
# - PowerShell 7 installed
# - Python 3.13+ installed and configured
# - Visual Studio Code installed with extensions
# - Git for Windows installed
# - Nutanix v4 API repository cloned and configured
# - VS Code opens with the API environment
```

## Advanced Examples

### Example 4: Automated Production Deployment

**Scenario**: Production environment deployment with pre-configured settings.

```powershell
# Step 1: Prepare production configuration
Copy-Item config\deployment-config.prod.json config\deployment-config.json
Copy-Item config\environment-config.full.json config\environment-config.json

# Step 2: Edit configuration files (or use environment variables)
$config = Get-Content config\deployment-config.json | ConvertFrom-Json
$config.prismCentral.ip = "10.1.1.100"
$config.prismCentral.username = "prod-admin"
# Note: Set password via environment variable for security
$config | ConvertTo-Json -Depth 10 | Set-Content config\deployment-config.json

# Step 3: Set credentials via environment variables
$env:PC_PASSWORD = "secure-production-password"
$env:VM_ADMIN_PASSWORD = "secure-vm-password"

# Step 4: Run automated deployment
.\Deploy-AutoWindows.ps1 -NonInteractive

# Expected result:
# - Production VM deployed with naming convention PROD-WIN-*
# - Complete API environment setup
# - All operations logged for audit
```

### Example 5: Multiple Environment Setup

**Scenario**: Set up development, staging, and production environments.

```powershell
# Development Environment
Write-Host "=== Setting up Development Environment ===" -ForegroundColor Green
Copy-Item config\deployment-config.dev.json config\deployment-config.json
.\Deploy-AutoWindows.ps1 -Phase 1 -NonInteractive

# Staging Environment  
Write-Host "=== Setting up Staging Environment ===" -ForegroundColor Yellow
# Modify config for staging
$config = Get-Content config\deployment-config.json | ConvertFrom-Json
$config.prismCentral.ip = "192.168.2.100"
$config.vmConfiguration.namePrefix = "STAGE-WIN-"
$config | ConvertTo-Json -Depth 10 | Set-Content config\deployment-config.json
.\Deploy-AutoWindows.ps1 -Phase 1 -NonInteractive

# Production Environment
Write-Host "=== Setting up Production Environment ===" -ForegroundColor Red
Copy-Item config\deployment-config.prod.json config\deployment-config.json
.\Deploy-AutoWindows.ps1 -Phase 1 -NonInteractive

# API Environment (once for all environments)
Write-Host "=== Setting up API Environment ===" -ForegroundColor Cyan
.\Deploy-AutoWindows.ps1 -Phase 2 -NonInteractive
```

### Example 6: Custom Component Installation

**Scenario**: Install additional development tools along with the standard API environment.

```powershell
# Step 1: Modify environment configuration for custom tools
$config = Get-Content config\environment-config.json | ConvertFrom-Json

# Add custom components
$config.components | Add-Member -NotePropertyName "docker" -NotePropertyValue @{
    install = $true
    downloadUrl = "https://desktop.docker.com/win/stable/Docker Desktop Installer.exe"
}

$config.components | Add-Member -NotePropertyName "terraform" -NotePropertyValue @{
    install = $true
    downloadUrl = "https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_windows_amd64.zip"
}

$config | ConvertTo-Json -Depth 10 | Set-Content config\environment-config.json

# Step 2: Run Phase 2 with custom components
.\Deploy-AutoWindows.ps1 -Phase 2

# Note: This requires extending the Install-NtnxEnvironment.ps1 script
# to handle the custom components
```

## Troubleshooting Examples

### Example 7: Configuration Validation

**Scenario**: Validate configuration before deployment to catch issues early.

```powershell
# Validate all configurations
.\Setup-Configuration.ps1 -Action Validate

# Expected output if valid:
# ===================================
#    Configuration Validation
# ===================================
# 
# Testing Prism Central connectivity...
# ✓ Prism Central is reachable
# ✓ Deployment configuration is valid
# ✓ Environment configuration is valid
# ✓ All configuration validations passed!

# Expected output if invalid:
# ===================================
#    Configuration Validation
# ===================================
# 
# ✗ Configuration validation failed:
#   - Prism Central IP is required
#   - Cannot reach Prism Central at 10.1.1.100
#   - Install path parent directory does not exist: C:\NonExistent
```

### Example 8: Partial Failure Recovery

**Scenario**: Phase 1 fails but user wants to continue with Phase 2.

```powershell
# Initial deployment attempt (fails at Phase 1)
.\Deploy-AutoWindows.ps1

# Expected output:
# Phase 1 failed: Network connectivity to Prism Central
# Continue with Phase 2? (Y/n): Y
# 
# ===================================
#    PHASE 2: Nutanix v4 API Environment Setup
# ===================================
# 
# Phase 2 completed successfully!

# Later, after fixing network issues, run Phase 1 separately
.\Deploy-AutoWindows.ps1 -Phase 1
```

### Example 9: Debug Mode Deployment

**Scenario**: Troubleshoot deployment issues with detailed logging.

```powershell
# Enable verbose logging and run deployment
$VerbosePreference = "Continue"
$DebugPreference = "Continue"

.\Deploy-AutoWindows.ps1 -Verbose -Debug

# Check detailed logs
Get-Content logs\deploy-auto-windows.log -Tail 100
Get-Content logs\phase1.log | Select-String "ERROR"
Get-Content logs\phase2.log | Select-String "WARN"
```

## Integration Examples

### Example 10: CI/CD Pipeline Integration

**Scenario**: Integrate Auto-Windows into Azure DevOps pipeline.

```yaml
# azure-pipelines.yml
trigger:
- main

pool:
  vmImage: 'windows-latest'

variables:
  PRISM_CENTRAL_IP: '10.1.1.100'
  PRISM_CENTRAL_USERNAME: 'ci-admin'

steps:
- checkout: self

- task: PowerShell@2
  displayName: 'Setup Configuration'
  inputs:
    targetType: 'inline'
    script: |
      # Use pipeline variables for configuration
      $config = Get-Content config\deployment-config.json | ConvertFrom-Json
      $config.prismCentral.ip = "$(PRISM_CENTRAL_IP)"
      $config.prismCentral.username = "$(PRISM_CENTRAL_USERNAME)"
      $config.vmConfiguration.namePrefix = "CI-WIN-$(Build.BuildId)-"
      $config | ConvertTo-Json -Depth 10 | Set-Content config\deployment-config.json

- task: PowerShell@2
  displayName: 'Deploy VM'
  inputs:
    targetType: 'filePath'
    filePath: 'Deploy-AutoWindows.ps1'
    arguments: '-Phase 1 -NonInteractive'
  env:
    PC_PASSWORD: $(PRISM_CENTRAL_PASSWORD)
    VM_ADMIN_PASSWORD: $(VM_ADMIN_PASSWORD)

- task: PowerShell@2
  displayName: 'Setup API Environment'
  inputs:
    targetType: 'filePath'
    filePath: 'Deploy-AutoWindows.ps1'
    arguments: '-Phase 2 -NonInteractive'

- task: PublishTestResults@2
  displayName: 'Publish Results'
  inputs:
    testResultsFiles: 'logs\*.log'
    testRunTitle: 'Auto-Windows Deployment'
```

### Example 11: PowerShell DSC Integration

**Scenario**: Use PowerShell Desired State Configuration for post-deployment configuration.

```powershell
# Step 1: Deploy with Auto-Windows
.\Deploy-AutoWindows.ps1

# Step 2: Apply DSC configuration to deployed VM
Configuration NutanixDevVM {
    param([string]$VMName)
    
    Node $VMName {
        WindowsFeature IIS {
            Ensure = "Present"
            Name = "IIS-WebServerRole"
        }
        
        File NutanixScripts {
            Ensure = "Present"
            Type = "Directory"
            DestinationPath = "C:\NutanixScripts"
        }
        
        Script DownloadAPITools {
            SetScript = {
                Invoke-WebRequest -Uri "https://github.com/nutanix/nutanix-api-examples/archive/main.zip" -OutFile "C:\temp\api-examples.zip"
                Expand-Archive -Path "C:\temp\api-examples.zip" -DestinationPath "C:\NutanixScripts"
            }
            TestScript = { Test-Path "C:\NutanixScripts\nutanix-api-examples-main" }
            GetScript = { @{ Result = "DownloadAPITools" } }
        }
    }
}

# Compile and apply configuration
$vmName = "DEV-WIN-1021-1430"  # From Phase 1 results
NutanixDevVM -VMName $vmName -OutputPath "C:\DSC\NutanixDevVM"
Start-DscConfiguration -Path "C:\DSC\NutanixDevVM" -ComputerName $vmName -Wait -Verbose
```

### Example 12: Terraform Integration

**Scenario**: Use Auto-Windows with Terraform for infrastructure as code.

```hcl
# main.tf
terraform {
  required_providers {
    nutanix = {
      source = "nutanix/nutanix"
      version = "~> 1.8"
    }
  }
}

provider "nutanix" {
  username = var.nutanix_username
  password = var.nutanix_password
  endpoint = var.nutanix_endpoint
  insecure = true
}

# Use null_resource to trigger Auto-Windows deployment
resource "null_resource" "auto_windows_deployment" {
  triggers = {
    cluster_id = var.cluster_uuid
  }
  
  provisioner "local-exec" {
    command = "powershell.exe -File Deploy-AutoWindows.ps1 -NonInteractive"
    
    environment = {
      PC_IP = var.nutanix_endpoint
      PC_USERNAME = var.nutanix_username
      PC_PASSWORD = var.nutanix_password
    }
  }
}

# Output the results
output "deployment_logs" {
  value = "Check logs directory for deployment results"
}
```

## Testing Examples

### Example 13: Unit Testing Configuration

**Scenario**: Test configuration validation without actual deployment.

```powershell
# Test script: Test-AutoWindowsConfig.ps1
Describe "Auto-Windows Configuration Tests" {
    Context "Deployment Configuration" {
        It "Should have valid Prism Central IP" {
            $config = Get-Content config\deployment-config.json | ConvertFrom-Json
            $config.prismCentral.ip | Should -Match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"
        }
        
        It "Should have required fields" {
            $config = Get-Content config\deployment-config.json | ConvertFrom-Json
            $config.prismCentral.username | Should -Not -BeNullOrEmpty
            $config.vmConfiguration.namePrefix | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Environment Configuration" {
        It "Should have valid install path" {
            $config = Get-Content config\environment-config.json | ConvertFrom-Json
            $parentPath = Split-Path $config.environment.installPath -Parent
            Test-Path $parentPath | Should -Be $true
        }
    }
}

# Run tests
Invoke-Pester Test-AutoWindowsConfig.ps1
```

### Example 14: Integration Testing

**Scenario**: Test the complete deployment process in a controlled environment.

```powershell
# Integration test script
$testResults = @{
    ConfigValidation = $false
    Phase1Deployment = $false
    Phase2Installation = $false
    ComponentValidation = $false
}

try {
    # Test 1: Configuration validation
    Write-Host "Testing configuration validation..." -ForegroundColor Cyan
    $configTest = .\Setup-Configuration.ps1 -Action Validate
    $testResults.ConfigValidation = $configTest
    
    # Test 2: Phase 1 deployment
    if ($testResults.ConfigValidation) {
        Write-Host "Testing Phase 1 deployment..." -ForegroundColor Cyan
        $phase1Result = .\Deploy-AutoWindows.ps1 -Phase 1 -NonInteractive
        $testResults.Phase1Deployment = $phase1Result.Success
    }
    
    # Test 3: Phase 2 installation
    Write-Host "Testing Phase 2 installation..." -ForegroundColor Cyan
    $phase2Result = .\Deploy-AutoWindows.ps1 -Phase 2 -NonInteractive
    $testResults.Phase2Installation = $phase2Result.Success
    
    # Test 4: Component validation
    if ($testResults.Phase2Installation) {
        Write-Host "Testing component installation..." -ForegroundColor Cyan
        $components = @{
            PowerShell7 = (Get-Command pwsh -ErrorAction SilentlyContinue) -ne $null
            Python = (Get-Command python -ErrorAction SilentlyContinue) -ne $null
            VSCode = (Get-Command code -ErrorAction SilentlyContinue) -ne $null
            Git = (Get-Command git -ErrorAction SilentlyContinue) -ne $null
        }
        $testResults.ComponentValidation = ($components.Values -contains $false) -eq $false
    }
    
    # Report results
    Write-Host "`n=== INTEGRATION TEST RESULTS ===" -ForegroundColor Yellow
    foreach ($test in $testResults.Keys) {
        $status = if ($testResults[$test]) { "PASS" } else { "FAIL" }
        $color = if ($testResults[$test]) { "Green" } else { "Red" }
        Write-Host "$test`: $status" -ForegroundColor $color
    }
    
    $overallResult = ($testResults.Values -contains $false) -eq $false
    $overallStatus = if ($overallResult) { "PASS" } else { "FAIL" }
    $overallColor = if ($overallResult) { "Green" } else { "Red" }
    Write-Host "Overall Result: $overallStatus" -ForegroundColor $overallColor
}
catch {
    Write-Host "Integration test failed: $($_.Exception.Message)" -ForegroundColor Red
}
```

## Performance Examples

### Example 15: Monitoring Deployment Performance

**Scenario**: Monitor and optimize deployment performance.

```powershell
# Performance monitoring wrapper
$performanceMetrics = @{
    StartTime = Get-Date
    Phase1Duration = $null
    Phase2Duration = $null
    TotalDuration = $null
    MemoryUsage = @()
    DiskUsage = @()
}

# Monitor system resources during deployment
$monitoringJob = Start-Job -ScriptBlock {
    while ($true) {
        $memory = Get-WmiObject Win32_OperatingSystem | Select-Object @{Name="MemoryUsage";Expression={"{0:N2}" -f ((($_.TotalVisibleMemorySize - $_.FreePhysicalMemory)*100)/ $_.TotalVisibleMemorySize)}}
        $disk = Get-WmiObject Win32_LogicalDisk | Where-Object {$_.DeviceID -eq "C:"} | Select-Object @{Name="DiskUsage";Expression={"{0:N2}" -f (($_.Size - $_.FreeSpace) / $_.Size * 100)}}
        
        Write-Output @{
            Timestamp = Get-Date
            Memory = $memory.MemoryUsage
            Disk = $disk.DiskUsage
        }
        
        Start-Sleep 30
    }
}

try {
    # Run Phase 1 with timing
    $phase1Start = Get-Date
    .\Deploy-AutoWindows.ps1 -Phase 1 -NonInteractive
    $performanceMetrics.Phase1Duration = (Get-Date) - $phase1Start
    
    # Run Phase 2 with timing
    $phase2Start = Get-Date  
    .\Deploy-AutoWindows.ps1 -Phase 2 -NonInteractive
    $performanceMetrics.Phase2Duration = (Get-Date) - $phase2Start
    
    $performanceMetrics.TotalDuration = (Get-Date) - $performanceMetrics.StartTime
    
    # Get resource usage data
    $resourceData = Receive-Job $monitoringJob
    $performanceMetrics.MemoryUsage = $resourceData | Select-Object -ExpandProperty Memory
    $performanceMetrics.DiskUsage = $resourceData | Select-Object -ExpandProperty Disk
}
finally {
    Stop-Job $monitoringJob
    Remove-Job $monitoringJob
}

# Report performance metrics
Write-Host "`n=== PERFORMANCE METRICS ===" -ForegroundColor Yellow
Write-Host "Phase 1 Duration: $($performanceMetrics.Phase1Duration.ToString('hh\:mm\:ss'))" -ForegroundColor White
Write-Host "Phase 2 Duration: $($performanceMetrics.Phase2Duration.ToString('hh\:mm\:ss'))" -ForegroundColor White  
Write-Host "Total Duration: $($performanceMetrics.TotalDuration.ToString('hh\:mm\:ss'))" -ForegroundColor White
Write-Host "Peak Memory Usage: $([math]::Round(($performanceMetrics.MemoryUsage | Measure-Object -Maximum).Maximum, 2))%" -ForegroundColor White
Write-Host "Peak Disk Usage: $([math]::Round(($performanceMetrics.DiskUsage | Measure-Object -Maximum).Maximum, 2))%" -ForegroundColor White
```

These examples demonstrate the flexibility and power of the Auto-Windows deployment system. Users can adapt these patterns to their specific requirements and environments.
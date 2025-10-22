# Auto-Windows: Usage Examples

This document provides practical examples for common Auto-Windows deployment scenarios with the enhanced automation features including intelligent IP discovery, HTTPS by default, and VM readiness testing.

## 🚀 Basic Examples

### Example 1: Complete Automated First-Time Setup

**Scenario**: New user wants complete end-to-end deployment with zero manual intervention.

```powershell
# Step 1: Clone the repository
git clone https://github.com/hardevsanghera/auto-windows.git
cd auto-windows

# Step 2: One-command complete deployment
.\Deploy-AutoWindows.ps1 -Phase All

# Expected interactive flow:
# ===================================
#    AUTO-WINDOWS DEPLOYMENT
# ===================================
# 
# Phase selection: All
# 
# ===================================
#    PHASE 1: Windows VM Deployment
# ===================================
# 
# Cloning VM deployment repository...
# Setting up Python environment...
# Starting VM deployment process...
# ✓ VM deployed successfully!
# VM UUID: 12345678-1234-5678-9abc-123456789def
# 
# ===================================
#    IP DISCOVERY & VM READINESS
# ===================================
# 
# Waiting for VM to get IP address...
# Attempt 1 of 30 - Checking VM IP status...
# ✓ IP Address discovered: 10.38.19.22
# 
# Testing VM readiness...
# ✓ Network connectivity successful
# ✓ WinRM HTTP available
# 
# WinRM HTTPS (port 5986) connection failed. This is common for new VMs.
# Would you like me to configure WinRM HTTPS on the remote VM? [Y/N]: Y
# 
# Setting up WinRM HTTPS on 10.38.19.22...
# ✓ Self-signed certificate created
# ✓ HTTPS listener configured
# ✓ Firewall rules added
# ✓ WinRM HTTPS is now available for secure connections
# 
# ===================================
#    PHASE 2: Nutanix v4 API Environment Setup
# ===================================
# 
# Connecting to VM via HTTPS...
# Installing PowerShell 7.4+...
# Installing Python 3.13...
# Installing Visual Studio Code 1.105+...
# Installing Git 2.42+...
# Setting up API repository...
# Creating Python virtual environment...
# Installing Python packages...
# 
# ===================================
#    EXECUTION SUMMARY
# ===================================
# 
# Phase 1 (VM Deployment): SUCCESS ✓
# IP Discovery: 10.38.19.22 ✓
# VM Readiness: HTTPS Configured ✓
# Phase 2 (API Environment): SUCCESS ✓
# Overall Status: SUCCESS ✓
```

### Example 2: Standalone API Environment Setup

**Scenario**: User has an existing VM and wants to setup the API environment only.

```powershell
# Direct API environment setup with HTTPS (default)
.\Setup-Phase2-ApiEnvironment.ps1 -VMIPAddress 10.38.19.22

# Expected flow:
# ===================================
#    NUTANIX V4 API ENVIRONMENT SETUP
# ===================================
# 
# Connecting to VM: 10.38.19.22
# Connection method: HTTPS (Port 5986)
# 
# Testing connectivity...
# ✓ HTTPS connection successful
# 
# Installing components...
# ✓ PowerShell 7.4.5 installed
# ✓ Python 3.13.0 installed
# ✓ VS Code 1.105.1 installed
# ✓ Git 2.42.0 installed
# ✓ Repository cloned: C:\Dev\ntnx-v4api-cats
# ✓ Virtual environment created
# ✓ Python packages installed
# 
# Environment ready! Next steps:
# 1. Edit C:\Dev\ntnx-v4api-cats\files\vars.txt
# 2. Run: code C:\Dev\ntnx-v4api-cats
```

### Example 3: VM Readiness Testing and Configuration

**Scenario**: Test VM connectivity and configure secure remoting before API setup.

```powershell
# Comprehensive VM readiness assessment
.\Test-VMReadiness.ps1 -VMIPAddress 10.38.19.22 -TestLevel Full -AddToTrusted

# Expected detailed output:
# ===================================
#    VM READINESS ASSESSMENT
# ===================================
# 
# Target VM: 10.38.19.22
# Test Level: Full
# 
# NETWORK CONNECTIVITY TESTS:
# ✓ Ping successful (Response time: 2ms)
# ✓ TCP Port 5985 (WinRM HTTP) - Open
# ✓ TCP Port 5986 (WinRM HTTPS) - Open
# ✓ TCP Port 3389 (RDP) - Open
# ✓ TCP Port 22 (SSH) - Closed
# 
# POWERSHELL REMOTING TESTS:
# ✓ WinRM HTTP session established
# ✓ WinRM HTTPS session established
# 
# SYSTEM PREREQUISITES:
# ✓ .NET Framework 4.8+ installed
# ✓ PowerShell 5.1+ available
# ✓ WMI service running
# ✓ Internet connectivity available
# 
# SECURITY CONFIGURATION:
# ✓ Added 10.38.19.22 to TrustedHosts
# ✓ PowerShell execution policy appropriate
# 
# OVERALL ASSESSMENT: READY FOR API SETUP ✓
```

### Example 4: Manual IP Discovery

**Scenario**: Discover VM IP address after deployment with custom parameters.

```powershell
# Enhanced IP discovery with extended timeout
.\Get-VMIPAddress.ps1 -MaxRetries 20 -RetryDelay 45

# Expected output:
# ===================================
#    VM IP ADDRESS DISCOVERY
# ===================================
# 
# Searching for most recent VM deployment...
# Found VM: DEV-WIN-1025-1430
# VM UUID: 44fee51f-5424-4752-8b66-e74e1ef317ab
# 
# Waiting for DHCP assignment...
# Attempt 1 of 20 - Checking VM IP status...
# VM Found: DEV-WIN-1025-1430
# Power State: ON
# ⚠ VM found but no IP assigned yet
# 
# Attempt 2 of 20 - Checking VM IP status...
# ✓ IP Address discovered: 10.38.19.22
# 
# IP Discovery Results:
# VM Name: DEV-WIN-1025-1430
# VM UUID: 44fee51f-5424-4752-8b66-e74e1ef317ab
# IP Address: 10.38.19.22
# Discovery Time: 45 seconds
```

## 🔧 Advanced Automation Examples

### Example 5: Complete Non-Interactive Deployment

**Scenario**: Fully automated deployment for CI/CD with environment variables.

```powershell
# Set environment variables for automation
$env:PC_USERNAME = "admin"
$env:PC_PASSWORD = "SecurePassword123!"
$env:VM_ADMIN_PASSWORD = "VMPassword123!"

# Run complete deployment without prompts
.\Deploy-AutoWindows.ps1 -Phase All -NonInteractive

# Expected automated flow:
# Auto-Windows deployment starting in non-interactive mode...
# Using environment variables for credentials
# Phase 1: VM deployment initiated...
# Phase 1: Completed successfully
# IP Discovery: Starting automatic discovery...
# IP Discovery: Found 10.38.19.22
# VM Readiness: Testing connectivity...
# VM Readiness: Configuring HTTPS automatically...
# Phase 2: Starting API environment setup...
# Phase 2: Completed successfully
# Deployment completed without user intervention
```

### Example 6: Staged Deployment with Validation

**Scenario**: Manual control over each phase with comprehensive validation between steps.

```powershell
# Phase 1: Deploy VM
Write-Host "=== PHASE 1: VM DEPLOYMENT ===" -ForegroundColor Green
.\Deploy-AutoWindows.ps1 -Phase 1

# Get deployment results
$phase1Results = Get-Content "temp\phase1_results.json" | ConvertFrom-Json
Write-Host "VM Deployed: $($phase1Results.VMName)" -ForegroundColor Yellow
Write-Host "VM UUID: $($phase1Results.VMUUID)" -ForegroundColor Yellow

# Phase 1.5: IP Discovery with validation
Write-Host "=== IP DISCOVERY ===" -ForegroundColor Cyan
$vmIP = .\Get-VMIPAddress.ps1 -VMUUID $phase1Results.VMUUID -MaxRetries 15
if (-not $vmIP) {
    Write-Error "Failed to discover VM IP address"
    exit 1
}
Write-Host "Discovered IP: $vmIP" -ForegroundColor Green

# Phase 1.7: Comprehensive VM Testing
Write-Host "=== VM READINESS TESTING ===" -ForegroundColor Magenta
$readinessResult = .\Test-VMReadiness.ps1 -VMIPAddress $vmIP -TestLevel Full -AddToTrusted
if (-not $readinessResult.OverallSuccess) {
    Write-Error "VM failed readiness assessment"
    exit 1
}
Write-Host "VM is ready for API environment setup" -ForegroundColor Green

# Phase 2: API Environment Setup
Write-Host "=== PHASE 2: API ENVIRONMENT SETUP ===" -ForegroundColor Blue
.\Setup-Phase2-ApiEnvironment.ps1 -VMIPAddress $vmIP

Write-Host "=== DEPLOYMENT COMPLETE ===" -ForegroundColor Green
Write-Host "VM IP: $vmIP"
Write-Host "API Environment: C:\Dev\ntnx-v4api-cats"
Write-Host "Ready for development!"
```

### Example 7: Multiple VM Deployment with Automation

**Scenario**: Deploy multiple VMs for different purposes (dev, test, staging).

```powershell
# Define multiple VM configurations
$vmConfigs = @(
    @{ Type = "Development"; Prefix = "DEV-WIN-"; IP = $null },
    @{ Type = "Testing"; Prefix = "TEST-WIN-"; IP = $null },
    @{ Type = "Staging"; Prefix = "STAGE-WIN-"; IP = $null }
)

foreach ($config in $vmConfigs) {
    Write-Host "=== Deploying $($config.Type) VM ===" -ForegroundColor Yellow
    
    # Update VM configuration
    $deployConfig = Get-Content "config\deployment-config.json" | ConvertFrom-Json
    $deployConfig.vmConfiguration.namePrefix = $config.Prefix
    $deployConfig | ConvertTo-Json -Depth 10 | Set-Content "config\deployment-config.json"
    
    # Deploy VM
    .\Deploy-AutoWindows.ps1 -Phase 1 -NonInteractive
    
    # Discover IP
    $vmIP = .\Get-VMIPAddress.ps1 -MaxRetries 10
    $config.IP = $vmIP
    
    # Test readiness
    .\Test-VMReadiness.ps1 -VMIPAddress $vmIP -TestLevel Standard -AddToTrusted
    
    Write-Host "$($config.Type) VM ready: $vmIP" -ForegroundColor Green
}

# Setup API environment on development VM
Write-Host "=== Setting up API Environment on Development VM ===" -ForegroundColor Cyan
$devVM = $vmConfigs | Where-Object { $_.Type -eq "Development" }
.\Setup-Phase2-ApiEnvironment.ps1 -VMIPAddress $devVM.IP

# Report summary
Write-Host "`n=== DEPLOYMENT SUMMARY ===" -ForegroundColor White
foreach ($config in $vmConfigs) {
    Write-Host "$($config.Type): $($config.IP)" -ForegroundColor Green
}
```

## 🔒 Security and HTTPS Examples

### Example 8: HTTPS Configuration Troubleshooting

**Scenario**: Troubleshoot and configure HTTPS when automatic setup fails.

```powershell
# Test current HTTPS status
$vmIP = "10.38.19.22"

Write-Host "Testing HTTPS connectivity..." -ForegroundColor Cyan
try {
    $sessionOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
    $session = New-PSSession -ComputerName $vmIP -Port 5986 -UseSSL -SessionOption $sessionOptions
    Remove-PSSession $session
    Write-Host "✓ HTTPS connection successful" -ForegroundColor Green
} catch {
    Write-Host "❌ HTTPS connection failed: $($_.Exception.Message)" -ForegroundColor Red
    
    # Manual HTTPS configuration
    Write-Host "Configuring HTTPS manually..." -ForegroundColor Yellow
    
    # Connect via HTTP to setup HTTPS
    $httpSession = New-PSSession -ComputerName $vmIP -Port 5985
    
    $httpsResult = Invoke-Command -Session $httpSession -ScriptBlock {
        # Create self-signed certificate
        $cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My
        
        # Configure HTTPS listener
        winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=\"$env:COMPUTERNAME\";CertificateThumbprint=\"$($cert.Thumbprint)\"}"
        
        # Configure firewall
        New-NetFirewallRule -DisplayName "WinRM HTTPS" -Direction Inbound -LocalPort 5986 -Protocol TCP -Action Allow -Profile Any
        
        return @{
            CertificateThumbprint = $cert.Thumbprint
            Hostname = $env:COMPUTERNAME
        }
    }
    
    Remove-PSSession $httpSession
    
    Write-Host "✓ HTTPS configured with certificate: $($httpsResult.CertificateThumbprint)" -ForegroundColor Green
    
    # Test HTTPS again
    Start-Sleep 5
    $testSession = New-PSSession -ComputerName $vmIP -Port 5986 -UseSSL -SessionOption $sessionOptions
    Remove-PSSession $testSession
    Write-Host "✓ HTTPS connection now working" -ForegroundColor Green
}
```

### Example 9: Production Security Configuration

**Scenario**: Configure Auto-Windows for production with strict security.

```powershell
# Production security configuration
$productionConfig = @{
    UseHTTPS = $true
    RequireValidCertificates = $true
    DisableSSLBypass = $true
    RequireKerberos = $true
    AuditLogging = $true
}

# Configure for production security
Write-Host "=== PRODUCTION SECURITY SETUP ===" -ForegroundColor Red

# Disable SSL bypass for production
$envConfig = Get-Content "config\environment-config.json" | ConvertFrom-Json
$envConfig.environment.connectivity.sessionOptions.skipCACheck = $false
$envConfig.environment.connectivity.sessionOptions.skipCNCheck = $false
$envConfig.environment.connectivity.sessionOptions.skipRevocationCheck = $false
$envConfig | ConvertTo-Json -Depth 10 | Set-Content "config\environment-config.json"

# Use proper certificates in production
Write-Host "⚠ Production deployment requires:" -ForegroundColor Yellow
Write-Host "  1. Valid SSL certificates on target VMs" -ForegroundColor White
Write-Host "  2. Kerberos authentication configured" -ForegroundColor White
Write-Host "  3. Certificate authority trust established" -ForegroundColor White
Write-Host "  4. Audit logging enabled" -ForegroundColor White

# Deploy with strict security
.\Setup-Phase2-ApiEnvironment.ps1 -VMIPAddress $vmIP -UseHTTPS:$true

# Verify security configuration
$session = New-PSSession -ComputerName $vmIP -Port 5986 -UseSSL -Authentication Kerberos
$securityValidation = Invoke-Command -Session $session -ScriptBlock {
    @{
        CertificateValid = (Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -like "*$env:COMPUTERNAME*" }).Count -gt 0
        HTTPSListenerActive = (Get-WSManInstance winrm/config/listener | Where-Object { $_.Transport -eq "HTTPS" }).Count -gt 0
        FirewallConfigured = (Get-NetFirewallRule -DisplayName "WinRM HTTPS" -ErrorAction SilentlyContinue).Enabled -eq "True"
    }
}
Remove-PSSession $session

Write-Host "Security Validation Results:" -ForegroundColor Cyan
Write-Host "Certificate Valid: $($securityValidation.CertificateValid)" -ForegroundColor $(if($securityValidation.CertificateValid) {"Green"} else {"Red"})
Write-Host "HTTPS Listener: $($securityValidation.HTTPSListenerActive)" -ForegroundColor $(if($securityValidation.HTTPSListenerActive) {"Green"} else {"Red"})
Write-Host "Firewall Configured: $($securityValidation.FirewallConfigured)" -ForegroundColor $(if($securityValidation.FirewallConfigured) {"Green"} else {"Red"})
```

## 🔧 Troubleshooting and Diagnostic Examples

### Example 10: Comprehensive Diagnostics

**Scenario**: Diagnose deployment issues with comprehensive testing.

```powershell
# Comprehensive diagnostic script
function Invoke-AutoWindowsDiagnostics {
    param([string]$VMIPAddress)
    
    $diagnostics = @{
        NetworkConnectivity = @{}
        PowerShellRemoting = @{}
        SystemPrerequisites = @{}
        ComponentStatus = @{}
        SecurityConfiguration = @{}
    }
    
    Write-Host "=== COMPREHENSIVE DIAGNOSTICS ===" -ForegroundColor Yellow
    Write-Host "Target: $VMIPAddress" -ForegroundColor White
    
    # Network Connectivity Tests
    Write-Host "`nNetwork Connectivity:" -ForegroundColor Cyan
    $diagnostics.NetworkConnectivity.Ping = Test-NetConnection $VMIPAddress -InformationLevel Quiet
    $diagnostics.NetworkConnectivity.WinRM_HTTP = Test-NetConnection $VMIPAddress -Port 5985 -InformationLevel Quiet
    $diagnostics.NetworkConnectivity.WinRM_HTTPS = Test-NetConnection $VMIPAddress -Port 5986 -InformationLevel Quiet
    $diagnostics.NetworkConnectivity.RDP = Test-NetConnection $VMIPAddress -Port 3389 -InformationLevel Quiet
    $diagnostics.NetworkConnectivity.SSH = Test-NetConnection $VMIPAddress -Port 22 -InformationLevel Quiet
    
    foreach ($test in $diagnostics.NetworkConnectivity.GetEnumerator()) {
        $status = if ($test.Value) { "✓" } else { "❌" }
        $color = if ($test.Value) { "Green" } else { "Red" }
        Write-Host "  $($test.Key): $status" -ForegroundColor $color
    }
    
    # PowerShell Remoting Tests
    Write-Host "`nPowerShell Remoting:" -ForegroundColor Cyan
    try {
        $httpSession = New-PSSession -ComputerName $VMIPAddress -Port 5985 -ErrorAction Stop
        $diagnostics.PowerShellRemoting.HTTP = $true
        Remove-PSSession $httpSession
        Write-Host "  HTTP Session: ✓" -ForegroundColor Green
    } catch {
        $diagnostics.PowerShellRemoting.HTTP = $false
        Write-Host "  HTTP Session: ❌ $($_.Exception.Message)" -ForegroundColor Red
    }
    
    try {
        $sessionOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
        $httpsSession = New-PSSession -ComputerName $VMIPAddress -Port 5986 -UseSSL -SessionOption $sessionOptions -ErrorAction Stop
        $diagnostics.PowerShellRemoting.HTTPS = $true
        Remove-PSSession $httpsSession
        Write-Host "  HTTPS Session: ✓" -ForegroundColor Green
    } catch {
        $diagnostics.PowerShellRemoting.HTTPS = $false
        Write-Host "  HTTPS Session: ❌ $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # System Prerequisites (if we can connect)
    if ($diagnostics.PowerShellRemoting.HTTP -or $diagnostics.PowerShellRemoting.HTTPS) {
        Write-Host "`nSystem Prerequisites:" -ForegroundColor Cyan
        
        $port = if ($diagnostics.PowerShellRemoting.HTTPS) { 5986 } else { 5985 }
        $useSSL = $diagnostics.PowerShellRemoting.HTTPS
        $sessionOptions = if ($useSSL) { New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck } else { $null }
        
        $session = if ($useSSL) {
            New-PSSession -ComputerName $VMIPAddress -Port $port -UseSSL -SessionOption $sessionOptions
        } else {
            New-PSSession -ComputerName $VMIPAddress -Port $port
        }
        
        $sysInfo = Invoke-Command -Session $session -ScriptBlock {
            $info = @{}
            
            # .NET Framework
            $dotNetVersion = Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -Name Release -ErrorAction SilentlyContinue
            $info.DotNetFramework = if ($dotNetVersion.Release -ge 461808) { $true } else { $false }
            
            # PowerShell Version
            $info.PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            $info.PowerShell5Plus = $PSVersionTable.PSVersion.Major -ge 5
            
            # WMI Service
            $wmiService = Get-Service -Name winmgmt -ErrorAction SilentlyContinue
            $info.WMIService = ($wmiService.Status -eq "Running")
            
            # Internet Connectivity
            try {
                $internetTest = Test-NetConnection google.com -Port 443 -InformationLevel Quiet
                $info.InternetConnectivity = $internetTest
            } catch {
                $info.InternetConnectivity = $false
            }
            
            # Available Components
            $info.Components = @{
                PowerShell7 = (Get-Command pwsh -ErrorAction SilentlyContinue) -ne $null
                Python = (Get-Command python -ErrorAction SilentlyContinue) -ne $null
                Git = (Get-Command git -ErrorAction SilentlyContinue) -ne $null
                VSCode = (Get-Command code -ErrorAction SilentlyContinue) -ne $null
            }
            
            return $info
        }
        
        Remove-PSSession $session
        
        $diagnostics.SystemPrerequisites = $sysInfo
        
        foreach ($prereq in @("DotNetFramework", "PowerShell5Plus", "WMIService", "InternetConnectivity")) {
            $status = if ($sysInfo[$prereq]) { "✓" } else { "❌" }
            $color = if ($sysInfo[$prereq]) { "Green" } else { "Red" }
            Write-Host "  $prereq`: $status" -ForegroundColor $color
        }
        
        Write-Host "`nInstalled Components:" -ForegroundColor Cyan
        foreach ($component in $sysInfo.Components.GetEnumerator()) {
            $status = if ($component.Value) { "✓" } else { "❌" }
            $color = if ($component.Value) { "Green" } else { "Red" }
            Write-Host "  $($component.Key): $status" -ForegroundColor $color
        }
        
        Write-Host "  PowerShell Version: $($sysInfo.PowerShellVersion)" -ForegroundColor White
    }
    
    # Overall Assessment
    Write-Host "`n=== DIAGNOSTIC SUMMARY ===" -ForegroundColor Yellow
    
    $readyForPhase2 = $diagnostics.NetworkConnectivity.Ping -and 
                      ($diagnostics.PowerShellRemoting.HTTP -or $diagnostics.PowerShellRemoting.HTTPS) -and
                      $diagnostics.SystemPrerequisites.PowerShell5Plus -and
                      $diagnostics.SystemPrerequisites.InternetConnectivity
    
    if ($readyForPhase2) {
        Write-Host "STATUS: READY FOR API ENVIRONMENT SETUP ✓" -ForegroundColor Green
        
        if ($diagnostics.PowerShellRemoting.HTTPS) {
            Write-Host "RECOMMENDED: Use HTTPS connection" -ForegroundColor Green
            Write-Host "COMMAND: .\Setup-Phase2-ApiEnvironment.ps1 -VMIPAddress $VMIPAddress" -ForegroundColor White
        } else {
            Write-Host "RECOMMENDED: Configure HTTPS first" -ForegroundColor Yellow
            Write-Host "COMMAND: .\Test-VMReadiness.ps1 -VMIPAddress $VMIPAddress -AddToTrusted" -ForegroundColor White
        }
    } else {
        Write-Host "STATUS: NOT READY - ISSUES DETECTED ❌" -ForegroundColor Red
        
        Write-Host "`nRECOMMENDED ACTIONS:" -ForegroundColor Yellow
        if (-not $diagnostics.NetworkConnectivity.Ping) {
            Write-Host "- Check network connectivity to $VMIPAddress" -ForegroundColor White
        }
        if (-not $diagnostics.PowerShellRemoting.HTTP -and -not $diagnostics.PowerShellRemoting.HTTPS) {
            Write-Host "- Enable PowerShell remoting on target VM" -ForegroundColor White
            Write-Host "- Check Windows Firewall settings" -ForegroundColor White
        }
        if (-not $diagnostics.SystemPrerequisites.InternetConnectivity) {
            Write-Host "- Verify internet connectivity on target VM" -ForegroundColor White
        }
    }
    
    return $diagnostics
}

# Run comprehensive diagnostics
$diagnostics = Invoke-AutoWindowsDiagnostics -VMIPAddress "10.38.19.22"
```

### Example 11: Automated Recovery and Retry

**Scenario**: Implement automated recovery for common deployment failures.

```powershell
# Automated recovery script
function Invoke-AutoWindowsWithRecovery {
    param(
        [ValidateSet("1", "2", "All")]
        [string]$Phase = "All",
        [int]$MaxRetries = 3,
        [int]$RetryDelay = 300  # 5 minutes
    )
    
    $attempt = 1
    $success = $false
    
    while ($attempt -le $MaxRetries -and -not $success) {
        Write-Host "=== DEPLOYMENT ATTEMPT $attempt of $MaxRetries ===" -ForegroundColor Yellow
        
        try {
            switch ($Phase) {
                "1" {
                    $result = .\Deploy-AutoWindows.ps1 -Phase 1 -NonInteractive
                    $success = $result.Success
                }
                "2" {
                    # For Phase 2, we need VM IP
                    $vmIP = .\Get-VMIPAddress.ps1 -MaxRetries 10
                    if ($vmIP) {
                        $result = .\Setup-Phase2-ApiEnvironment.ps1 -VMIPAddress $vmIP
                        $success = $result.Success
                    } else {
                        throw "Failed to discover VM IP address"
                    }
                }
                "All" {
                    # Phase 1
                    $phase1Result = .\Deploy-AutoWindows.ps1 -Phase 1 -NonInteractive
                    if (-not $phase1Result.Success) {
                        throw "Phase 1 failed: $($phase1Result.Error)"
                    }
                    
                    # IP Discovery with retry
                    $vmIP = .\Get-VMIPAddress.ps1 -MaxRetries 15 -RetryDelay 60
                    if (-not $vmIP) {
                        throw "Failed to discover VM IP after extended waiting"
                    }
                    
                    # VM Readiness with auto-configuration
                    $readinessResult = .\Test-VMReadiness.ps1 -VMIPAddress $vmIP -TestLevel Full -AddToTrusted
                    if (-not $readinessResult.OverallSuccess) {
                        Write-Warning "VM readiness issues detected, attempting automatic fixes..."
                        
                        # Auto-configure HTTPS if needed
                        if (-not $readinessResult.WinRM_HTTPS) {
                            Write-Host "Configuring HTTPS automatically..." -ForegroundColor Yellow
                            # HTTPS configuration code here
                        }
                    }
                    
                    # Phase 2
                    $phase2Result = .\Setup-Phase2-ApiEnvironment.ps1 -VMIPAddress $vmIP
                    if (-not $phase2Result.Success) {
                        throw "Phase 2 failed: $($phase2Result.Error)"
                    }
                    
                    $success = $true
                }
            }
            
            if ($success) {
                Write-Host "✓ Deployment successful on attempt $attempt" -ForegroundColor Green
                return $true
            }
        }
        catch {
            Write-Host "❌ Attempt $attempt failed: $($_.Exception.Message)" -ForegroundColor Red
            
            if ($attempt -lt $MaxRetries) {
                Write-Host "Waiting $($RetryDelay) seconds before retry..." -ForegroundColor Yellow
                Start-Sleep $RetryDelay
                
                # Cleanup before retry
                Write-Host "Cleaning up for retry..." -ForegroundColor Cyan
                
                # Clear password cache
                .\Deploy-AutoWindows.ps1 -DelPw -ErrorAction SilentlyContinue
                
                # Clean temporary files
                if (Test-Path "temp") {
                    Remove-Item "temp\*" -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        $attempt++
    }
    
    Write-Host "❌ All deployment attempts failed" -ForegroundColor Red
    return $false
}

# Usage with automatic recovery
$deploymentSuccess = Invoke-AutoWindowsWithRecovery -Phase "All" -MaxRetries 3 -RetryDelay 300
```

## 🚀 Performance and Monitoring Examples

### Example 12: Deployment Performance Monitoring

**Scenario**: Monitor deployment performance and resource usage.

```powershell
# Performance monitoring with detailed metrics
function Start-DeploymentWithMonitoring {
    param([string]$Phase = "All")
    
    $performanceData = @{
        StartTime = Get-Date
        Phases = @{}
        ResourceUsage = @()
        NetworkMetrics = @()
    }
    
    # Start resource monitoring
    $monitorJob = Start-Job -ScriptBlock {
        param($VMIPAddress)
        
        while ($true) {
            $timestamp = Get-Date
            
            # Local resource usage
            $process = Get-Process -Name powershell -ErrorAction SilentlyContinue | Measure-Object WorkingSet -Sum
            $memory = Get-WmiObject Win32_OperatingSystem
            $disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
            
            $localMetrics = @{
                Timestamp = $timestamp
                PowerShellMemory = [math]::Round($process.Sum / 1MB, 2)
                SystemMemoryUsed = [math]::Round((($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory) / $memory.TotalVisibleMemorySize) * 100, 2)
                DiskUsed = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 2)
            }
            
            # Network metrics if VM IP available
            if ($VMIPAddress) {
                $networkTest = Test-NetConnection $VMIPAddress -InformationLevel Detailed -ErrorAction SilentlyContinue
                if ($networkTest) {
                    $localMetrics.NetworkLatency = $networkTest.PingReplyDetails.RoundtripTime
                }
            }
            
            Write-Output $localMetrics
            Start-Sleep 30
        }
    } -ArgumentList $null
    
    try {
        if ($Phase -eq "All" -or $Phase -eq "1") {
            Write-Host "=== PHASE 1 PERFORMANCE MONITORING ===" -ForegroundColor Yellow
            $phase1Start = Get-Date
            
            $phase1Result = .\Deploy-AutoWindows.ps1 -Phase 1 -NonInteractive
            
            $performanceData.Phases.Phase1 = @{
                Duration = (Get-Date) - $phase1Start
                Success = $phase1Result.Success
                VMName = $phase1Result.VMName
                VMUUID = $phase1Result.VMUUID
            }
            
            if ($phase1Result.Success) {
                # Update monitoring job with VM IP when available
                $vmIP = .\Get-VMIPAddress.ps1 -VMUUID $phase1Result.VMUUID -MaxRetries 10
                if ($vmIP) {
                    $performanceData.Phases.Phase1.IPDiscoveryTime = (Get-Date) - $phase1Start
                    $performanceData.Phases.Phase1.VMIPAddress = $vmIP
                    
                    # Restart monitoring job with VM IP
                    Stop-Job $monitorJob -ErrorAction SilentlyContinue
                    Remove-Job $monitorJob -ErrorAction SilentlyContinue
                    
                    $monitorJob = Start-Job -ScriptBlock {
                        param($VMIPAddress)
                        # Same monitoring script but with VM IP
                    } -ArgumentList $vmIP
                }
            }
        }
        
        if (($Phase -eq "All" -or $Phase -eq "2") -and $vmIP) {
            Write-Host "=== PHASE 2 PERFORMANCE MONITORING ===" -ForegroundColor Yellow
            $phase2Start = Get-Date
            
            $phase2Result = .\Setup-Phase2-ApiEnvironment.ps1 -VMIPAddress $vmIP
            
            $performanceData.Phases.Phase2 = @{
                Duration = (Get-Date) - $phase2Start
                Success = $phase2Result.Success
                ComponentsInstalled = $phase2Result.ValidationResults
                ConnectionMethod = $phase2Result.ConnectionMethod
            }
        }
        
        # Collect resource usage data
        $performanceData.ResourceUsage = Receive-Job $monitorJob
        $performanceData.TotalDuration = (Get-Date) - $performanceData.StartTime
        
    }
    finally {
        Stop-Job $monitorJob -ErrorAction SilentlyContinue
        Remove-Job $monitorJob -ErrorAction SilentlyContinue
    }
    
    # Generate performance report
    Write-Host "`n=== PERFORMANCE REPORT ===" -ForegroundColor Cyan
    Write-Host "Total Deployment Time: $($performanceData.TotalDuration.ToString('hh\:mm\:ss'))" -ForegroundColor White
    
    if ($performanceData.Phases.Phase1) {
        Write-Host "Phase 1 Duration: $($performanceData.Phases.Phase1.Duration.ToString('mm\:ss'))" -ForegroundColor White
        if ($performanceData.Phases.Phase1.IPDiscoveryTime) {
            Write-Host "IP Discovery Time: $($performanceData.Phases.Phase1.IPDiscoveryTime.ToString('mm\:ss'))" -ForegroundColor White
        }
    }
    
    if ($performanceData.Phases.Phase2) {
        Write-Host "Phase 2 Duration: $($performanceData.Phases.Phase2.Duration.ToString('mm\:ss'))" -ForegroundColor White
        Write-Host "Connection Method: $($performanceData.Phases.Phase2.ConnectionMethod)" -ForegroundColor White
    }
    
    if ($performanceData.ResourceUsage) {
        $avgMemory = ($performanceData.ResourceUsage | Measure-Object PowerShellMemory -Average).Average
        $peakMemory = ($performanceData.ResourceUsage | Measure-Object PowerShellMemory -Maximum).Maximum
        $avgLatency = ($performanceData.ResourceUsage | Where-Object NetworkLatency | Measure-Object NetworkLatency -Average).Average
        
        Write-Host "Resource Usage:" -ForegroundColor Yellow
        Write-Host "  Average PowerShell Memory: $([math]::Round($avgMemory, 2)) MB" -ForegroundColor White
        Write-Host "  Peak PowerShell Memory: $([math]::Round($peakMemory, 2)) MB" -ForegroundColor White
        if ($avgLatency) {
            Write-Host "  Average Network Latency: $([math]::Round($avgLatency, 2)) ms" -ForegroundColor White
        }
    }
    
    return $performanceData
}

# Run deployment with performance monitoring
$performanceResults = Start-DeploymentWithMonitoring -Phase "All"
```

These comprehensive examples demonstrate the full capabilities of the enhanced Auto-Windows system, including intelligent IP discovery, HTTPS by default, VM readiness testing, and comprehensive automation features. Users can adapt these patterns to their specific requirements and environments.
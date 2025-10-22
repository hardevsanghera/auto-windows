#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Remotely configure WinRM HTTPS (port 5986) on target VM

.DESCRIPTION
    Uses existing WinRM HTTP connection to remotely configure HTTPS listener
    on the target VM, including SSL certificate creation and firewall rules.

.PARAMETER VMIPAddress
    IP address of the target VM

.PARAMETER VMCredential
    Credentials for the VM (if not provided, will prompt)

.EXAMPLE
    .\Enable-RemoteWinRMHTTPS.ps1 -VMIPAddress 10.38.19.22
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$VMIPAddress = "10.38.19.22",
    
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$VMCredential
)

# Import password manager for getting VM credentials
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptRoot "PasswordManager.ps1") -Force

function Get-VMCredentials {
    Write-Host "🔐 Getting VM Credentials..." -ForegroundColor Cyan
    
    # Try to get cached VM administrator password
    $vmPassword = Get-CachedPassword -Username "vm-administrator"
    
    if ($vmPassword) {
        Write-Host "✓ Using cached password for: vm-administrator" -ForegroundColor Green
        $securePassword = ConvertTo-SecureString $vmPassword -AsPlainText -Force
        return New-Object System.Management.Automation.PSCredential("Administrator", $securePassword)
    } else {
        Write-Host "[INFO] No cached VM password found. Please enter credentials." -ForegroundColor Yellow
        return Get-Credential -UserName "Administrator" -Message "Enter credentials for VM Administrator"
    }
}

Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "   REMOTELY ENABLE WINRM HTTPS ON TARGET VM" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "Target VM: $VMIPAddress" -ForegroundColor White

# Get credentials if not provided
if (-not $VMCredential) {
    $VMCredential = Get-VMCredentials
    if (-not $VMCredential) {
        Write-Host "❌ Cannot proceed without VM credentials." -ForegroundColor Red
        exit 1
    }
}

# Test if WinRM HTTP is available
Write-Host "`n🔍 Testing WinRM HTTP connectivity..." -ForegroundColor Cyan
try {
    Test-WSMan -ComputerName $VMIPAddress -ErrorAction Stop | Out-Null
    Write-Host "✓ WinRM HTTP is available on $VMIPAddress" -ForegroundColor Green
} catch {
    Write-Host "❌ WinRM HTTP is not available: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Cannot proceed without WinRM HTTP connectivity." -ForegroundColor Yellow
    exit 1
}

# Create remote session and configure HTTPS
Write-Host "`n🔧 Configuring WinRM HTTPS remotely..." -ForegroundColor Cyan
try {
    # Create PowerShell session
    Write-Host "   Creating remote PowerShell session..." -ForegroundColor Gray
    $session = New-PSSession -ComputerName $VMIPAddress -Credential $VMCredential -ErrorAction Stop
    Write-Host "✓ Remote session established" -ForegroundColor Green
    
    # Execute configuration commands on remote VM
    Write-Host "   Executing HTTPS configuration commands..." -ForegroundColor Gray
    $configResult = Invoke-Command -Session $session -ScriptBlock {
        $results = @{}
        
        try {
            # 1. Create self-signed certificate
            Write-Output "Creating SSL certificate..."
            $cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME, "localhost" `
                -CertStoreLocation "Cert:\LocalMachine\My" `
                -KeyUsage DigitalSignature, KeyEncipherment `
                -KeyAlgorithm RSA `
                -KeyLength 2048 `
                -HashAlgorithm SHA256 `
                -NotAfter (Get-Date).AddYears(5) `
                -Subject "CN=$env:COMPUTERNAME" `
                -FriendlyName "WinRM HTTPS Certificate"
            
            $results.Certificate = @{
                Success = $true
                Thumbprint = $cert.Thumbprint
                Subject = $cert.Subject
            }
            
        } catch {
            $results.Certificate = @{
                Success = $false
                Error = $_.Exception.Message
            }
        }
        
        try {
            # 2. Remove existing HTTPS listener (if any)
            Write-Output "Removing existing HTTPS listener..."
            Remove-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{Transport="HTTPS"; Address="*"} -ErrorAction SilentlyContinue
            
            # 3. Create new HTTPS listener
            Write-Output "Creating HTTPS listener on port 5986..."
            New-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{Transport="HTTPS"; Address="*"} -ValueSet @{
                Hostname = $env:COMPUTERNAME
                CertificateThumbprint = $cert.Thumbprint
                Port = 5986
            }
            
            $results.Listener = @{
                Success = $true
                Port = 5986
                Hostname = $env:COMPUTERNAME
            }
            
        } catch {
            $results.Listener = @{
                Success = $false
                Error = $_.Exception.Message
            }
        }
        
        try {
            # 4. Configure WinRM service settings
            Write-Output "Configuring WinRM service settings..."
            Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true -Force
            Set-Item WSMan:\localhost\Service\Auth\Certificate -Value $true -Force
            
            $results.ServiceConfig = @{
                Success = $true
                BasicAuth = $true
                CertAuth = $true
            }
            
        } catch {
            $results.ServiceConfig = @{
                Success = $false
                Error = $_.Exception.Message
            }
        }
        
        try {
            # 5. Configure Windows Firewall
            Write-Output "Configuring Windows Firewall..."
            Remove-NetFirewallRule -DisplayName "WinRM HTTPS" -ErrorAction SilentlyContinue
            New-NetFirewallRule -DisplayName "WinRM HTTPS" `
                -Description "Allow inbound WinRM HTTPS traffic on port 5986" `
                -Direction Inbound `
                -Protocol TCP `
                -LocalPort 5986 `
                -Action Allow `
                -Profile Any `
                -Enabled True
            
            $results.Firewall = @{
                Success = $true
                Rule = "WinRM HTTPS - Port 5986"
            }
            
        } catch {
            $results.Firewall = @{
                Success = $false
                Error = $_.Exception.Message
            }
        }
        
        try {
            # 6. Restart WinRM service
            Write-Output "Restarting WinRM service..."
            Restart-Service WinRM -Force
            Start-Sleep -Seconds 3
            
            $service = Get-Service WinRM
            $results.ServiceRestart = @{
                Success = $service.Status -eq "Running"
                Status = $service.Status.ToString()
            }
            
        } catch {
            $results.ServiceRestart = @{
                Success = $false
                Error = $_.Exception.Message
            }
        }
        
        try {
            # 7. Verify HTTPS listener
            Write-Output "Verifying HTTPS listener..."
            $httpsListener = Get-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{Transport="HTTPS"}
            
            $results.Verification = @{
                Success = $true
                Port = $httpsListener.Port
                Certificate = $httpsListener.CertificateThumbprint
            }
            
        } catch {
            $results.Verification = @{
                Success = $false
                Error = $_.Exception.Message
            }
        }
        
        return $results
    }
    
    # Clean up session
    Remove-PSSession -Session $session
    
    # Display results
    Write-Host "`n📊 Configuration Results:" -ForegroundColor Cyan
    
    $allSuccess = $true
    
    if ($configResult.Certificate.Success) {
        Write-Host "✓ SSL Certificate Created" -ForegroundColor Green
        Write-Host "    Thumbprint: $($configResult.Certificate.Thumbprint)" -ForegroundColor Gray
    } else {
        Write-Host "✗ SSL Certificate Failed: $($configResult.Certificate.Error)" -ForegroundColor Red
        $allSuccess = $false
    }
    
    if ($configResult.Listener.Success) {
        Write-Host "✓ HTTPS Listener Created" -ForegroundColor Green
        Write-Host "    Port: $($configResult.Listener.Port)" -ForegroundColor Gray
        Write-Host "    Hostname: $($configResult.Listener.Hostname)" -ForegroundColor Gray
    } else {
        Write-Host "✗ HTTPS Listener Failed: $($configResult.Listener.Error)" -ForegroundColor Red
        $allSuccess = $false
    }
    
    if ($configResult.ServiceConfig.Success) {
        Write-Host "✓ WinRM Service Configured" -ForegroundColor Green
        Write-Host "    Basic Auth: $($configResult.ServiceConfig.BasicAuth)" -ForegroundColor Gray
        Write-Host "    Certificate Auth: $($configResult.ServiceConfig.CertAuth)" -ForegroundColor Gray
    } else {
        Write-Host "✗ Service Configuration Failed: $($configResult.ServiceConfig.Error)" -ForegroundColor Red
        $allSuccess = $false
    }
    
    if ($configResult.Firewall.Success) {
        Write-Host "✓ Windows Firewall Configured" -ForegroundColor Green
        Write-Host "    Rule: $($configResult.Firewall.Rule)" -ForegroundColor Gray
    } else {
        Write-Host "✗ Firewall Configuration Failed: $($configResult.Firewall.Error)" -ForegroundColor Red
        $allSuccess = $false
    }
    
    if ($configResult.ServiceRestart.Success) {
        Write-Host "✓ WinRM Service Restarted" -ForegroundColor Green
        Write-Host "    Status: $($configResult.ServiceRestart.Status)" -ForegroundColor Gray
    } else {
        Write-Host "✗ Service Restart Failed: $($configResult.ServiceRestart.Error)" -ForegroundColor Red
        $allSuccess = $false
    }
    
    if ($configResult.Verification.Success) {
        Write-Host "✓ HTTPS Listener Verified" -ForegroundColor Green
        Write-Host "    Port: $($configResult.Verification.Port)" -ForegroundColor Gray
        Write-Host "    Certificate: $($configResult.Verification.Certificate)" -ForegroundColor Gray
    } else {
        Write-Host "✗ Verification Failed: $($configResult.Verification.Error)" -ForegroundColor Red
        $allSuccess = $false
    }
    
    if ($allSuccess) {
        Write-Host "`n🎉 WinRM HTTPS successfully configured on $VMIPAddress!" -ForegroundColor Green
        Write-Host "`n🔗 Test HTTPS connection:" -ForegroundColor Cyan
        Write-Host "   Test-WSMan -ComputerName $VMIPAddress -UseSSL -Port 5986" -ForegroundColor White
        Write-Host "`n🔗 Create secure PowerShell session:" -ForegroundColor Cyan
        Write-Host "   `$sessionOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck" -ForegroundColor White
        Write-Host "   `$session = New-PSSession -ComputerName $VMIPAddress -Port 5986 -UseSSL -SessionOption `$sessionOptions -Credential (Get-Credential)" -ForegroundColor White
    } else {
        Write-Host "`n❌ Some configuration steps failed. Check the errors above." -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ Failed to configure WinRM HTTPS: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
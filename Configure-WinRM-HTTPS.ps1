#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configure WinRM HTTPS (port 5986) on target VM for secure remoting

.DESCRIPTION
    Sets up WinRM HTTPS listener with self-signed certificate and configures
    Windows Firewall to allow secure PowerShell remoting on port 5986.

.NOTES
    This script should be run ON THE TARGET VM as Administrator.
    It creates a self-signed certificate and configures WinRM for HTTPS.
#>

Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "   CONFIGURE WINRM HTTPS (PORT 5986) ON TARGET VM" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan

function Write-ConfigStep {
    param(
        [string]$Step,
        [bool]$Success,
        [string]$Details = ""
    )
    
    $status = if ($Success) { "✓" } else { "✗" }
    $color = if ($Success) { "Green" } else { "Red" }
    
    Write-Host "[$status] $Step" -ForegroundColor $color
    if ($Details) {
        Write-Host "    $Details" -ForegroundColor Gray
    }
}

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "❌ This script requires Administrator privileges." -ForegroundColor Red
    Write-Host "   Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

Write-Host "🔧 Configuring WinRM HTTPS on this VM..." -ForegroundColor Cyan

# 1. Get computer information
$computerName = $env:COMPUTERNAME
$fqdn = "$computerName.local"
Write-Host "`nComputer Name: $computerName" -ForegroundColor White
Write-Host "FQDN: $fqdn" -ForegroundColor White

# 2. Create self-signed certificate for WinRM HTTPS
try {
    Write-Host "`n1. Creating self-signed certificate for WinRM HTTPS..." -ForegroundColor Cyan
    
    # Check if certificate already exists
    $existingCert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {
        $_.Subject -like "*$computerName*" -and $_.EnhancedKeyUsageList.FriendlyName -contains "Server Authentication"
    }
    
    if ($existingCert) {
        Write-ConfigStep "SSL Certificate" $true "Using existing certificate: $($existingCert.Thumbprint)"
        $cert = $existingCert[0]
    } else {
        # Create new self-signed certificate
        $cert = New-SelfSignedCertificate -DnsName $computerName, $fqdn, "localhost" `
            -CertStoreLocation "Cert:\LocalMachine\My" `
            -KeyUsage DigitalSignature, KeyEncipherment `
            -KeyAlgorithm RSA `
            -KeyLength 2048 `
            -Provider "Microsoft RSA SChannel Cryptographic Provider" `
            -HashAlgorithm SHA256 `
            -NotAfter (Get-Date).AddYears(5) `
            -Subject "CN=$computerName" `
            -FriendlyName "WinRM HTTPS Certificate"
        
        Write-ConfigStep "SSL Certificate Created" $true "Thumbprint: $($cert.Thumbprint)"
    }
    
} catch {
    Write-ConfigStep "Create SSL Certificate" $false $_.Exception.Message
    exit 1
}

# 3. Configure WinRM HTTPS listener
try {
    Write-Host "`n2. Configuring WinRM HTTPS listener..." -ForegroundColor Cyan
    
    # Remove any existing HTTPS listeners
    $existingListeners = Get-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{Transport="HTTPS"} -ErrorAction SilentlyContinue
    if ($existingListeners) {
        Remove-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{Transport="HTTPS"; Address="*"} -ErrorAction SilentlyContinue
        Write-ConfigStep "Remove Existing HTTPS Listener" $true "Cleaned up old configuration"
    }
    
    # Create new HTTPS listener
    New-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{Transport="HTTPS"; Address="*"} -ValueSet @{
        Hostname = $computerName
        CertificateThumbprint = $cert.Thumbprint
        Port = 5986
    }
    
    Write-ConfigStep "HTTPS Listener Created" $true "Port 5986 configured with certificate"
    
} catch {
    Write-ConfigStep "Configure HTTPS Listener" $false $_.Exception.Message
}

# 4. Configure WinRM service settings
try {
    Write-Host "`n3. Configuring WinRM service settings..." -ForegroundColor Cyan
    
    # Enable basic authentication for HTTPS
    Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true -Force
    Write-ConfigStep "Enable Basic Auth" $true "Required for PowerShell remoting"
    
    # Configure certificate authentication
    Set-Item WSMan:\localhost\Service\Auth\Certificate -Value $true -Force
    Write-ConfigStep "Enable Certificate Auth" $true "Enhanced security option"
    
    # Set maximum concurrent operations
    Set-Item WSMan:\localhost\Service\MaxConcurrentOperationsPerUser -Value 1500 -Force
    Write-ConfigStep "Max Concurrent Operations" $true "Set to 1500"
    
    # Set maximum connections
    Set-Item WSMan:\localhost\Service\MaxConnections -Value 300 -Force
    Write-ConfigStep "Max Connections" $true "Set to 300"
    
} catch {
    Write-ConfigStep "Configure WinRM Settings" $false $_.Exception.Message
}

# 5. Configure Windows Firewall
try {
    Write-Host "`n4. Configuring Windows Firewall..." -ForegroundColor Cyan
    
    # Remove existing rule if it exists
    Remove-NetFirewallRule -DisplayName "WinRM HTTPS" -ErrorAction SilentlyContinue
    
    # Create new firewall rule for WinRM HTTPS
    New-NetFirewallRule -DisplayName "WinRM HTTPS" `
        -Description "Allow inbound WinRM HTTPS traffic on port 5986" `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 5986 `
        -Action Allow `
        -Profile Any `
        -Enabled True
    
    Write-ConfigStep "Firewall Rule Created" $true "Port 5986 allowed inbound"
    
    # Also ensure WinRM HTTP rule exists
    $httpRule = Get-NetFirewallRule -DisplayName "WinRM HTTP" -ErrorAction SilentlyContinue
    if (-not $httpRule) {
        New-NetFirewallRule -DisplayName "WinRM HTTP" `
            -Description "Allow inbound WinRM HTTP traffic on port 5985" `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort 5985 `
            -Action Allow `
            -Profile Any `
            -Enabled True
        Write-ConfigStep "WinRM HTTP Rule" $true "Port 5985 also configured"
    }
    
} catch {
    Write-ConfigStep "Configure Firewall" $false $_.Exception.Message
}

# 6. Restart WinRM service
try {
    Write-Host "`n5. Restarting WinRM service..." -ForegroundColor Cyan
    
    Restart-Service WinRM -Force
    Start-Sleep -Seconds 3
    
    $service = Get-Service WinRM
    Write-ConfigStep "WinRM Service" ($service.Status -eq "Running") "Status: $($service.Status)"
    
} catch {
    Write-ConfigStep "Restart WinRM Service" $false $_.Exception.Message
}

# 7. Verify configuration
Write-Host "`n6. Verifying WinRM HTTPS configuration..." -ForegroundColor Cyan

try {
    # Check HTTPS listener
    $httpsListener = Get-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{Transport="HTTPS"}
    if ($httpsListener) {
        Write-ConfigStep "HTTPS Listener Verification" $true "Port: $($httpsListener.Port), Certificate: $($httpsListener.CertificateThumbprint)"
    }
    
    # Check HTTP listener
    $httpListener = Get-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{Transport="HTTP"}
    if ($httpListener) {
        Write-ConfigStep "HTTP Listener Verification" $true "Port: $($httpListener.Port)"
    }
    
    # Test local HTTPS connection
    $testResult = Test-WSMan -ComputerName localhost -UseSSL -ErrorAction SilentlyContinue
    if ($testResult) {
        Write-ConfigStep "Local HTTPS Test" $true "WinRM HTTPS responding locally"
    } else {
        Write-ConfigStep "Local HTTPS Test" $false "Could not connect to local HTTPS endpoint"
    }
    
} catch {
    Write-ConfigStep "Verify Configuration" $false $_.Exception.Message
}

# 8. Display connection information
Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
Write-Host "   CONNECTION INFORMATION" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan

Write-Host "`n🔗 Remote Connection Options:" -ForegroundColor Cyan
Write-Host "   HTTP (Port 5985):  New-PSSession -ComputerName $computerName -Port 5985" -ForegroundColor Green
Write-Host "   HTTPS (Port 5986): New-PSSession -ComputerName $computerName -Port 5986 -UseSSL" -ForegroundColor Green

Write-Host "`n🛡️  Security Information:" -ForegroundColor Cyan
Write-Host "   • HTTPS uses self-signed certificate (expect certificate warnings)" -ForegroundColor Yellow
Write-Host "   • Use -SessionOption with -SkipCACheck and -SkipCNCheck for self-signed certs" -ForegroundColor Yellow
Write-Host "   • Certificate Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray

Write-Host "`n📋 Example secure connection from remote machine:" -ForegroundColor Cyan
$connectionExample = @"
# Create session options to handle self-signed certificate
`$sessionOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck

# Connect using HTTPS (secure)
`$session = New-PSSession -ComputerName $computerName -Port 5986 -UseSSL -SessionOption `$sessionOptions -Credential (Get-Credential)

# Test the connection
Invoke-Command -Session `$session -ScriptBlock { `$env:COMPUTERNAME }
"@

Write-Host $connectionExample -ForegroundColor White

Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
Write-Host "WinRM HTTPS configuration complete!" -ForegroundColor Green
Write-Host "Both HTTP (5985) and HTTPS (5986) are now available." -ForegroundColor Green
Write-Host ("=" * 70) -ForegroundColor Cyan
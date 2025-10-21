#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Connect to VM via RDP to enable PowerShell remoting

.DESCRIPTION
    Opens RDP connection to the target VM and provides instructions for enabling
    PowerShell remoting on the remote machine.

.PARAMETER VMIPAddress
    IP address of the target VM

.EXAMPLE
    .\Connect-ViaRDP.ps1 -VMIPAddress 10.38.19.26
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$VMIPAddress = "10.38.19.26"
)

Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "   CONNECT TO VM VIA RDP" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "Target VM: $VMIPAddress" -ForegroundColor White

# Get VM credentials
Write-Host "`n🔐 Getting VM Credentials..." -ForegroundColor Cyan
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptRoot "PasswordManager.ps1") -Force

$vmPassword = Get-CachedPassword -Username "vm-administrator"
if ($vmPassword) {
    Write-Host "✓ Using cached password for: vm-administrator" -ForegroundColor Green
    Write-Host "Username: Administrator" -ForegroundColor Yellow
    # Convert SecureString to plain text for display
    if ($vmPassword -is [System.Security.SecureString]) {
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($vmPassword))
        Write-Host "Password: $plainPassword" -ForegroundColor Yellow
    } else {
        Write-Host "Password: $vmPassword" -ForegroundColor Yellow
    }
} else {
    Write-Host "[INFO] No cached VM password found." -ForegroundColor Yellow
    Write-Host "You'll need to enter the Administrator password manually." -ForegroundColor Yellow
}

Write-Host "`n🖥️  Opening RDP Connection..." -ForegroundColor Cyan
Write-Host "Starting Remote Desktop Connection to $VMIPAddress..." -ForegroundColor Gray

# Create RDP file for easier connection
$rdpContent = @"
full address:s:$VMIPAddress
username:s:Administrator
screen mode id:i:2
use multimon:i:0
desktopwidth:i:1920
desktopheight:i:1080
session bpp:i:32
winposstr:s:0,1,0,0,800,600
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
displayconnectionbar:i:1
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
audiomode:i:0
redirectprinters:i:1
redirectcomports:i:0
redirectsmartcards:i:1
redirectclipboard:i:1
redirectposdevices:i:0
autoreconnection enabled:i:1
authentication level:i:2
prompt for credentials:i:0
negotiate security layer:i:1
remoteapplicationmode:i:0
alternate shell:s:
shell working directory:s:
gatewayhostname:s:
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
promptcredentialonce:i:0
gatewaybrokeringtype:i:0
use redirection server name:i:0
rdgiskdcproxy:i:0
kdcproxyname:s:
"@

$rdpFile = Join-Path $env:TEMP "vm-connection.rdp"
$rdpContent | Out-File -FilePath $rdpFile -Encoding ASCII

try {
    # Launch RDP
    Start-Process "mstsc.exe" -ArgumentList "/f", $rdpFile
    Write-Host "✓ RDP connection launched" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to launch RDP: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Trying alternative method..." -ForegroundColor Yellow
    Start-Process "mstsc.exe" -ArgumentList "/v:$VMIPAddress"
}

Write-Host "`n📋 Once connected to the VM, run these commands in PowerShell as Administrator:" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Gray

$commands = @"
# Enable PowerShell Remoting
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Configure WinRM settings
Set-Item WSMan:\localhost\Service\Auth\Basic -Value `$true
Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value `$true
Set-Item WSMan:\localhost\Listener\*\Port -Value 5985

# Configure Windows Firewall
New-NetFirewallRule -DisplayName "WinRM HTTP" -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow
New-NetFirewallRule -DisplayName "WinRM HTTPS" -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow

# Restart WinRM service
Restart-Service WinRM

# Verify configuration
Get-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{Address="*";Transport="HTTP"}
"@

Write-Host $commands -ForegroundColor White
Write-Host ("=" * 70) -ForegroundColor Gray

Write-Host "`n🔄 After running those commands on the VM:" -ForegroundColor Cyan
Write-Host "1. Close the RDP session" -ForegroundColor Yellow
Write-Host "2. Run .\Test-VMReadiness.ps1 again to verify connectivity" -ForegroundColor Yellow
Write-Host "3. If successful, you'll be ready for Phase 2!" -ForegroundColor Yellow

Write-Host "`n⚠️  Alternative: Copy and run the VM setup script" -ForegroundColor Cyan

# Create a setup script that can be copied to the VM
$vmSetupScript = @'
#!/usr/bin/env pwsh
# VM Setup Script for PowerShell Remoting
Write-Host "Configuring VM for PowerShell Remoting..." -ForegroundColor Cyan

try {
    # Enable PowerShell Remoting
    Write-Host "1. Enabling PowerShell Remoting..." -ForegroundColor Yellow
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Write-Host "   ✓ PowerShell Remoting enabled" -ForegroundColor Green

    # Configure WinRM settings
    Write-Host "2. Configuring WinRM..." -ForegroundColor Yellow
    Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true -Force
    Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true -Force
    Write-Host "   ✓ WinRM authentication configured" -ForegroundColor Green

    # Configure Windows Firewall
    Write-Host "3. Configuring Windows Firewall..." -ForegroundColor Yellow
    New-NetFirewallRule -DisplayName "WinRM HTTP" -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "WinRM HTTPS" -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow -ErrorAction SilentlyContinue
    Write-Host "   ✓ Firewall rules configured" -ForegroundColor Green

    # Restart WinRM service
    Write-Host "4. Restarting WinRM service..." -ForegroundColor Yellow
    Restart-Service WinRM
    Write-Host "   ✓ WinRM service restarted" -ForegroundColor Green

    Write-Host "`nVM is now configured for PowerShell Remoting!" -ForegroundColor Green
    Write-Host "You can now connect remotely from your host machine." -ForegroundColor Cyan

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please run this script as Administrator" -ForegroundColor Yellow
}
'@

$vmScriptPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "VM-Setup-PowerShell-Remoting.ps1"
$vmSetupScript | Out-File -FilePath $vmScriptPath -Encoding UTF8

Write-Host "`n💾 Created script for VM: VM-Setup-PowerShell-Remoting.ps1" -ForegroundColor Green
Write-Host "   Copy this file to the VM and run as Administrator" -ForegroundColor Gray

Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
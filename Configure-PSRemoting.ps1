#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configure local machine for PowerShell remoting to VM

.DESCRIPTION
    Configures the local machine to allow PowerShell remoting to the target VM
    by adding it to TrustedHosts and configuring WinRM settings.

.PARAMETER VMIPAddress
    IP address of the target VM

.EXAMPLE
    .\Configure-PSRemoting.ps1 -VMIPAddress 10.38.19.26
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$VMIPAddress = "10.38.19.26"
)

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

Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "   CONFIGURE POWERSHELL REMOTING TO VM" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "Target VM: $VMIPAddress" -ForegroundColor White

Write-Host "`n🔧 Configuring WinRM and TrustedHosts..." -ForegroundColor Cyan

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "❌ This script requires Administrator privileges." -ForegroundColor Red
    Write-Host "   Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

# 1. Enable WinRM on local machine
try {
    Write-Host "`n1. Enabling WinRM on local machine..." -ForegroundColor Cyan
    $winrmStatus = Get-Service -Name "WinRM" -ErrorAction Stop
    
    if ($winrmStatus.Status -ne "Running") {
        Start-Service -Name "WinRM" -ErrorAction Stop
        Write-ConfigStep "Start WinRM Service" $true "Service started successfully"
    } else {
        Write-ConfigStep "WinRM Service Status" $true "Already running"
    }
    
    # Enable WinRM if needed
    winrm get winrm/config/client 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        winrm quickconfig -quiet
        Write-ConfigStep "WinRM Quick Config" ($LASTEXITCODE -eq 0) "Configured WinRM client"
    } else {
        Write-ConfigStep "WinRM Configuration" $true "Already configured"
    }
    
} catch {
    Write-ConfigStep "Enable WinRM" $false $_.Exception.Message
}

# 2. Configure TrustedHosts
try {
    Write-Host "`n2. Configuring TrustedHosts..." -ForegroundColor Cyan
    
    $currentTrustedHosts = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
    Write-Host "   Current TrustedHosts: '$currentTrustedHosts'" -ForegroundColor Gray
    
    if ($currentTrustedHosts -eq "" -or $null -eq $currentTrustedHosts) {
        # No trusted hosts configured, add our VM
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value $VMIPAddress -Force
        Write-ConfigStep "Add VM to TrustedHosts" $true "Added $VMIPAddress"
    } elseif ($currentTrustedHosts -notlike "*$VMIPAddress*") {
        # Trusted hosts exist but our VM is not in the list
        $newTrustedHosts = "$currentTrustedHosts,$VMIPAddress"
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value $newTrustedHosts -Force
        Write-ConfigStep "Add VM to TrustedHosts" $true "Added $VMIPAddress to existing list"
    } else {
        Write-ConfigStep "VM in TrustedHosts" $true "$VMIPAddress already trusted"
    }
    
    # Verify the configuration
    $updatedTrustedHosts = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value
    Write-Host "   Updated TrustedHosts: '$updatedTrustedHosts'" -ForegroundColor Gray
    
} catch {
    Write-ConfigStep "Configure TrustedHosts" $false $_.Exception.Message
}

# 3. Configure WinRM client settings for better compatibility
try {
    Write-Host "`n3. Optimizing WinRM client settings..." -ForegroundColor Cyan
    
    # Allow unencrypted traffic (for HTTP WinRM)
    Set-Item WSMan:\localhost\Client\AllowUnencrypted -Value $true -Force
    Write-ConfigStep "Allow Unencrypted Traffic" $true "Enabled for IP-based connections"
    
    # Set authentication methods
    Set-Item WSMan:\localhost\Client\Auth\Basic -Value $true -Force
    Write-ConfigStep "Enable Basic Authentication" $true "Required for some scenarios"
    
    # Increase timeout values
    Set-Item WSMan:\localhost\Client\NetworkDelayms -Value 5000 -Force
    Write-ConfigStep "Network Delay Timeout" $true "Set to 5 seconds"
    
} catch {
    Write-ConfigStep "Optimize WinRM Settings" $false $_.Exception.Message
}

# 4. Test the configuration
Write-Host "`n4. Testing PowerShell remoting..." -ForegroundColor Cyan

try {
    # Try to create a test session
    Write-Host "   Attempting to connect to $VMIPAddress..." -ForegroundColor Gray
    
    # Get VM credentials
    Write-Host "`n🔐 Getting VM Credentials..." -ForegroundColor Cyan
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    Import-Module (Join-Path $scriptRoot "PasswordManager.ps1") -Force
    
    $vmPassword = Get-CachedPassword -Username "vm-administrator"
    if ($vmPassword) {
        Write-Host "✓ Using cached password for: vm-administrator" -ForegroundColor Green
        $securePassword = ConvertTo-SecureString $vmPassword -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential("Administrator", $securePassword)
    } else {
        Write-Host "[INFO] No cached VM password found. Please enter credentials." -ForegroundColor Yellow
        $credential = Get-Credential -UserName "Administrator" -Message "Enter credentials for VM Administrator"
    }
    
    # Test connection with explicit credential and connection options
    $sessionOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck
    $testSession = New-PSSession -ComputerName $VMIPAddress -Credential $credential -SessionOption $sessionOptions -ErrorAction Stop
    
    if ($testSession) {
        Write-ConfigStep "PowerShell Remote Session" $true "Successfully connected to $VMIPAddress"
        
        # Test a simple command
        $remoteInfo = Invoke-Command -Session $testSession -ScriptBlock {
            [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                CurrentUser = $env:USERNAME
                OSVersion = (Get-ComputerInfo).WindowsProductName
            }
        }
        
        Write-Host "`n   Remote VM Information:" -ForegroundColor Cyan
        Write-Host "   Computer Name: $($remoteInfo.ComputerName)" -ForegroundColor Green
        Write-Host "   PowerShell Version: $($remoteInfo.PowerShellVersion)" -ForegroundColor Green  
        Write-Host "   Current User: $($remoteInfo.CurrentUser)" -ForegroundColor Green
        Write-Host "   OS Version: $($remoteInfo.OSVersion)" -ForegroundColor Green
        
        # Clean up
        Remove-PSSession -Session $testSession
        Write-ConfigStep "Connection Test Complete" $true "VM is ready for PowerShell remoting"
        
    }
    
} catch {
    Write-ConfigStep "PowerShell Remote Connection" $false $_.Exception.Message
    Write-Host "`n   Troubleshooting Tips:" -ForegroundColor Yellow
    Write-Host "   • Verify VM Administrator password is correct" -ForegroundColor Gray
    Write-Host "   • Check Windows Firewall on the VM" -ForegroundColor Gray
    Write-Host "   • Ensure WinRM service is running on the VM" -ForegroundColor Gray
    Write-Host "   • Try connecting via RDP first to enable WinRM on VM" -ForegroundColor Gray
}

Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
Write-Host "Configuration complete! Run Test-VMReadiness.ps1 again to verify." -ForegroundColor Green
Write-Host ("=" * 70) -ForegroundColor Cyan
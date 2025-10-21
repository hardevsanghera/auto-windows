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

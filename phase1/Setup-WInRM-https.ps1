# Complete WinRM HTTPS Setup Script for Windows Server 2022
# Run as Administrator

Write-Host "Configuring WinRM with HTTPS..." -ForegroundColor Yellow

# Step 1: Enable PSRemoting
Write-Host "1. Enabling PowerShell Remoting..." -ForegroundColor Green
Enable-PSRemoting -Force

# Step 2: Configure WinRM Service
Write-Host "2. Configuring WinRM Service..." -ForegroundColor Green
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM
winrm quickconfig -q

# Step 3: Create Self-Signed Certificate
Write-Host "3. Creating Self-Signed Certificate..." -ForegroundColor Green
$cert = New-SelfSignedCertificate -CertStoreLocation Cert:\LocalMachine\My -DnsName $env:COMPUTERNAME -NotAfter (Get-Date).AddYears(5)
$thumbprint = $cert.Thumbprint
Write-Host "Certificate Thumbprint: $thumbprint" -ForegroundColor Cyan

# Step 4: Remove existing HTTPS listeners and create new one
Write-Host "4. Configuring HTTPS Listener..." -ForegroundColor Green
Get-ChildItem WSMan:\Localhost\listener | Where-Object Keys -eq "Transport=HTTPS" | Remove-Item -Recurse -Force
New-Item -Path WSMan:\LocalHost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $thumbprint -Force

# Step 5: Configure Firewall
Write-Host "5. Configuring Firewall..." -ForegroundColor Green
Enable-NetFirewallRule -DisplayName "Windows Remote Management (HTTPS-In)" -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "WinRM HTTPS" -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow -ErrorAction SilentlyContinue

# Step 6: Configure Authentication
Write-Host "6. Configuring Authentication..." -ForegroundColor Green
Set-Item WSMan:\localhost\Service\Auth\Basic $true
Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB 1024
Set-Item WSMan:\localhost\Service\MaxConcurrentOperationsPerUser 100

# Step 7: Verify Configuration
Write-Host "7. Verifying Configuration..." -ForegroundColor Green
try {
    Test-WSMan -ComputerName localhost -UseSSL
    Write-Host "✅ WinRM HTTPS configuration successful!" -ForegroundColor Green
} catch {
    Write-Host "❌ WinRM HTTPS test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Display configuration summary
Write-Host "`n📋 Configuration Summary:" -ForegroundColor Cyan
Write-Host "- Computer Name: $env:COMPUTERNAME" -ForegroundColor White
Write-Host "- HTTPS Port: 5986" -ForegroundColor White
Write-Host "- Certificate Thumbprint: $thumbprint" -ForegroundColor White
Write-Host "- Service Status: $((Get-Service WinRM).Status)" -ForegroundColor White

Write-Host "`n🔗 Test connection from remote machine using:" -ForegroundColor Yellow
Write-Host "Test-WSMan -ComputerName $env:COMPUTERNAME -UseSSL -Port 5986" -ForegroundColor White

# List all listeners
Write-Host "`n📡 Active WinRM Listeners:" -ForegroundColor Cyan
winrm enumerate winrm/config/listener
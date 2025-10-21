# Enabling WinRM HTTPS (Port 5986) on Target VM

## Overview
To enable secure PowerShell remoting using HTTPS on port 5986, you need to configure both WinRM and Windows Firewall on the target VM. This provides encrypted communication for remote PowerShell sessions.

## Option 1: Automated Script (Recommended)

I've created a comprehensive script `Configure-WinRM-HTTPS.ps1` that automates the entire process:

### To use the script:
1. **Copy the script to your target VM** (10.38.19.26)
2. **Run PowerShell as Administrator** on the VM
3. **Execute the script:**
   ```powershell
   .\Configure-WinRM-HTTPS.ps1
   ```

### What the script does:
- ✅ Creates a self-signed SSL certificate
- ✅ Configures WinRM HTTPS listener on port 5986
- ✅ Sets up Windows Firewall rules
- ✅ Configures authentication methods
- ✅ Restarts WinRM service
- ✅ Verifies the configuration

## Option 2: Manual Configuration

If you prefer to configure manually, run these commands **on the target VM as Administrator**:

### Step 1: Create SSL Certificate
```powershell
# Create self-signed certificate for WinRM HTTPS
$computerName = $env:COMPUTERNAME
$cert = New-SelfSignedCertificate -DnsName $computerName, "localhost" `
    -CertStoreLocation "Cert:\LocalMachine\My" `
    -KeyUsage DigitalSignature, KeyEncipherment `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -HashAlgorithm SHA256 `
    -NotAfter (Get-Date).AddYears(5) `
    -Subject "CN=$computerName" `
    -FriendlyName "WinRM HTTPS Certificate"
```

### Step 2: Configure WinRM HTTPS Listener
```powershell
# Remove existing HTTPS listener (if any)
Remove-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{Transport="HTTPS"; Address="*"} -ErrorAction SilentlyContinue

# Create new HTTPS listener
New-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{Transport="HTTPS"; Address="*"} -ValueSet @{
    Hostname = $computerName
    CertificateThumbprint = $cert.Thumbprint
    Port = 5986
}
```

### Step 3: Configure WinRM Settings
```powershell
# Enable authentication methods
Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true -Force
Set-Item WSMan:\localhost\Service\Auth\Certificate -Value $true -Force

# Configure connection limits
Set-Item WSMan:\localhost\Service\MaxConcurrentOperationsPerUser -Value 1500 -Force
Set-Item WSMan:\localhost\Service\MaxConnections -Value 300 -Force
```

### Step 4: Configure Windows Firewall
```powershell
# Allow WinRM HTTPS traffic
New-NetFirewallRule -DisplayName "WinRM HTTPS" `
    -Description "Allow inbound WinRM HTTPS traffic on port 5986" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 5986 `
    -Action Allow `
    -Profile Any `
    -Enabled True
```

### Step 5: Restart WinRM Service
```powershell
Restart-Service WinRM -Force
```

### Step 6: Verify Configuration
```powershell
# Check HTTPS listener
Get-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{Transport="HTTPS"}

# Test local HTTPS connection
Test-WSMan -ComputerName localhost -UseSSL
```

## Using HTTPS Remoting from Your Host Machine

Once port 5986 is configured on the VM, connect from your host machine using:

### Secure Connection Example:
```powershell
# Create session options for self-signed certificate
$sessionOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck

# Connect using HTTPS (port 5986)
$session = New-PSSession -ComputerName 10.38.19.26 -Port 5986 -UseSSL -SessionOption $sessionOptions -Credential (Get-Credential)

# Test the connection
Invoke-Command -Session $session -ScriptBlock { $env:COMPUTERNAME }

# Clean up
Remove-PSSession $session
```

### Updated Test Command:
After configuring HTTPS, run our readiness test:
```powershell
.\Test-VMReadiness.ps1 -TestLevel Full
```

## Security Benefits of HTTPS (Port 5986)

- 🔒 **Encrypted Communication**: All data transmitted is encrypted using TLS/SSL
- 🛡️ **Certificate Authentication**: Can use certificate-based authentication
- 🔐 **Data Integrity**: Prevents tampering during transmission
- 📊 **Compliance**: Meets security requirements for production environments

## Troubleshooting Port 5986

If you encounter issues:

1. **Verify certificate**: `Get-ChildItem Cert:\LocalMachine\My`
2. **Check listener**: `Get-WSManInstance -ResourceURI winrm/config/listener`
3. **Test firewall**: `Test-NetConnection -ComputerName 10.38.19.26 -Port 5986`
4. **Review logs**: Check Windows Event Viewer → Applications and Services Logs → Microsoft → Windows → WinRM

## Next Steps

Once port 5986 is configured:
1. Run `.\Test-VMReadiness.ps1 -TestLevel Full` to verify both HTTP and HTTPS connectivity
2. Your VM will be 100% ready for Phase 2 Nutanix v4 API setup
3. You'll have secure, encrypted PowerShell remoting capability for all future operations
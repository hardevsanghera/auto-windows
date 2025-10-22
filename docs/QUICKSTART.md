# Auto-Windows: Quick Start Guide

## 🚀 Get Started in 5 Minutes

Auto-Windows provides a complete two-phase automation solution for deploying Windows VMs and setting up Nutanix v4 API development environments with intelligent automation and secure HTTPS connectivity.

## ✅ Prerequisites

- **PowerShell 5.1+** (PowerShell 7+ recommended)
- **Windows OS** (Windows 10/11, Windows Server 2019/2022)
- **Internet connectivity** (for repository downloads)
- **Nutanix Prism Central access** (for VM deployment)
- **Administrative privileges** (recommended for Phase 2)

## 🏃‍♂️ Quick Start

### 1. Download Auto-Windows
```powershell
git clone https://github.com/hardevsanghera/auto-windows.git
cd auto-windows
```

### 2. Complete Automated Deployment
```powershell
# Deploy VM and setup API environment with full automation
.\Deploy-AutoWindows.ps1 -Phase All
```

**That's it!** The script will:
- Deploy your Windows VM (Phase 1)
- Automatically discover the VM's IP address
- Test VM readiness and configure secure HTTPS remoting
- Setup the complete API development environment (Phase 2)

## 🎯 Alternative Execution Options

### Individual Phases
```powershell
# VM deployment only
.\Deploy-AutoWindows.ps1 -Phase 1

# API environment setup only (requires VM IP)
.\Deploy-AutoWindows.ps1 -Phase 2
```

### Standalone API Environment Setup
```powershell
# Setup API environment on existing VM with HTTPS (default)
.\Setup-Phase2-ApiEnvironment.ps1 -VMIPAddress 10.38.19.22

# Force HTTP if needed
.\Setup-Phase2-ApiEnvironment.ps1 -VMIPAddress 10.38.19.22 -UseHTTPS:$false
```

### VM Testing and Preparation
```powershell
# Test VM connectivity and setup secure remoting
.\Test-VMReadiness.ps1 -VMIPAddress 10.38.19.22 -AddToTrusted -TestLevel Full
```

## 🔍 IP Discovery and Automation

### Automatic IP Discovery
The system automatically discovers VM IP addresses after deployment:
```powershell
# Manual IP discovery if needed
$vmIP = .\Get-VMIPAddress.ps1
Write-Host "VM IP Address: $vmIP"
```

### Waiting for VM Readiness
Auto-Windows intelligently waits for VMs to be ready:
- **15-minute timeout** for IP assignment
- **30-second intervals** with retry logic
- **Interactive prompts** for extended waiting

## 🔒 Security Features

### HTTPS by Default
- **Secure PowerShell remoting** using port 5986
- **SSL certificate bypass** for lab environments
- **Automatic WinRM HTTPS setup** on target VMs

### Interactive HTTPS Configuration
When connecting to VMs without HTTPS:
```
WinRM HTTPS (port 5986) connection failed. This is common for new VMs.
Would you like me to configure WinRM HTTPS on the remote VM? [Y/N]: Y

Setting up WinRM HTTPS on 10.38.19.22...
✓ Self-signed certificate created
✓ HTTPS listener configured  
✓ Firewall rules added
✓ WinRM HTTPS is now available
```

## 🛠️ Configuration Options

### Quick Configuration Templates
```powershell
# Development environment
Copy-Item config\deployment-config.dev.json config\deployment-config.json

# Production environment
Copy-Item config\deployment-config.prod.json config\deployment-config.json
```

### Interactive Setup
```powershell
# Guided configuration
.\Setup-Configuration.ps1 -Action Setup -Interactive
```

## ✅ Validation and Testing

### Pre-deployment Validation
```powershell
# Validate configuration
.\Setup-Configuration.ps1 -Action Validate

# Test connectivity
.\Setup-Configuration.ps1 -Action Test
```

### VM Readiness Assessment
```powershell
# Basic connectivity test
.\Test-VMReadiness.ps1 -VMIPAddress 10.38.19.22

# Comprehensive assessment
.\Test-VMReadiness.ps1 -VMIPAddress 10.38.19.22 -TestLevel Full
```

## 🤖 Non-Interactive Mode

For automation and CI/CD:
```powershell
# Fully automated deployment
.\Deploy-AutoWindows.ps1 -NonInteractive

# Skip prerequisite checks
.\Deploy-AutoWindows.ps1 -SkipPrerequisites

# Custom configuration
.\Deploy-AutoWindows.ps1 -ConfigDirectory "environments\production"
```

## 🔍 Troubleshooting

### Check Execution Logs
```powershell
# Main execution log
Get-Content logs\deploy-auto-windows.log -Tail 50

# Phase-specific logs
Get-Content logs\phase1.log -Tail 20
Get-Content logs\phase2.log -Tail 20
```

### Common Issues and Solutions

#### VM Not Getting IP Address
```powershell
# Extended waiting with more retries
.\Get-VMIPAddress.ps1 -MaxRetries 10 -RetryDelay 60
```

#### PowerShell Remoting Issues
```powershell
# Test and configure remoting
.\Test-VMReadiness.ps1 -VMIPAddress <IP> -AddToTrusted
```

#### HTTPS Configuration Problems
The script will automatically prompt to configure HTTPS when needed.

#### Clear Cached Passwords
```powershell
# Reset password cache
.\Deploy-AutoWindows.ps1 -DelPw
```

### Reset Configuration
```powershell
# Reset to defaults
.\Setup-Configuration.ps1 -Action Reset
```

## 🎯 What Gets Deployed

### Phase 1: Windows VM
- **Nutanix AHV deployment** using Python automation
- **Interactive resource selection** (cluster, network, image)
- **Sysprep customization** for Windows configuration
- **DHCP-enabled networking** with automatic IP discovery

### Phase 2: Complete API Environment
- **PowerShell 7.4+** for cross-platform scripting
- **Python 3.13+** with virtual environment
- **Visual Studio Code 1.105+** with extensions (PowerShell, Python, YAML)
- **Git 2.42+** for version control
- **Nutanix v4 API repository** with samples and documentation
- **Python packages**: requests, pandas, openpyxl, urllib3

## 🚀 Next Steps

After successful deployment:

### 1. Configure API Environment
```powershell
# Edit Nutanix connection details
notepad C:\Dev\ntnx-v4api-cats\files\vars.txt
```

### 2. Test API Scripts
```powershell
# Navigate to API environment
cd C:\Dev\ntnx-v4api-cats
python examples\get-clusters.py
```

### 3. Use VS Code for Development
```powershell
# Open in VS Code
code C:\Dev\ntnx-v4api-cats
```

## 🔗 Advanced Documentation

- **[Advanced Usage](ADVANCED.md)** - Comprehensive configuration and customization
- **[Usage Examples](EXAMPLES.md)** - Real-world deployment scenarios
- **[Configuration Guide](../config/README.md)** - Detailed configuration options

## 🆘 Support and Resources

- **Logs**: Detailed execution tracking in `logs\` directory
- **Configuration**: Interactive setup with validation tools
- **Community**: Report issues via repository issue tracker
- **Source**: [Nutanix v4 API Repo](https://github.com/hardevsanghera/ntnx-v4api-cats)

## 🎉 Success!

Your Windows VM with complete Nutanix v4 API development environment is ready! The system provides:
- **Secure HTTPS connectivity** for PowerShell remoting
- **Complete development stack** (PowerShell, Python, VS Code, Git)
- **Ready-to-use API samples** and comprehensive documentation
- **Intelligent automation** that handles common setup challenges
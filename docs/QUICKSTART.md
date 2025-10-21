# Auto-Windows: Quick Start Guide

## Overview

Auto-Windows provides a complete two-phase automation solution for deploying Windows VMs and setting up Nutanix v4 API development environments.

## Prerequisites

- **PowerShell 5.1+** (PowerShell 7+ recommended)
- **Windows OS** (tested on Windows 10/11, Windows Server 2019/2022)
- **Internet connectivity** (to download external repositories)
- **Nutanix Prism Central access** (for VM deployment)
- **Administrative privileges** (recommended for some installations)

## Quick Start (5 minutes)

### 1. Download Auto-Windows
```powershell
git clone https://github.com/your-org/auto-windows.git
cd auto-windows
```

### 2. Configure Your Environment
```powershell
# Interactive configuration setup
.\Setup-Configuration.ps1 -Action Setup -Interactive
```

### 3. Run Complete Deployment
```powershell
# Deploy VM and setup API environment
.\Deploy-AutoWindows.ps1
```

## Configuration Options

### Development Environment (Recommended for testing)
```powershell
# Copy development template
Copy-Item config\deployment-config.dev.json config\deployment-config.json

# Edit with your Prism Central details
notepad config\deployment-config.json
```

### Production Environment
```powershell
# Copy production template
Copy-Item config\deployment-config.prod.json config\deployment-config.json

# Configure for production use
.\Setup-Configuration.ps1 -Action Setup -ConfigType prod -Interactive
```

## Phase-Specific Execution

### Phase 1 Only (VM Deployment)
```powershell
.\Deploy-AutoWindows.ps1 -Phase 1
```

### Phase 2 Only (API Environment Setup)
```powershell
.\Deploy-AutoWindows.ps1 -Phase 2
```

## Validation and Testing

### Validate Configuration
```powershell
.\Setup-Configuration.ps1 -Action Validate
```

### Test Connectivity
```powershell
.\Setup-Configuration.ps1 -Action Test -ConfigType dev
```

## Non-Interactive Mode

For automation scenarios:
```powershell
.\Deploy-AutoWindows.ps1 -NonInteractive
```

## Troubleshooting

### Check Logs
```powershell
# View main execution log
Get-Content logs\deploy-auto-windows.log -Tail 50

# View phase-specific logs
Get-Content logs\phase1.log
Get-Content logs\phase2.log
```

### Reset Configuration
```powershell
.\Setup-Configuration.ps1 -Action Reset
```

### Prerequisites Issues
```powershell
# Skip prerequisite checks if needed
.\Deploy-AutoWindows.ps1 -SkipPrerequisites
```

## Next Steps

After successful deployment:

1. **Configure API Environment**: Edit `C:\Dev\ntnx-v4api-cats\files\vars.txt` with your Nutanix details
2. **Test API Scripts**: Run the Nutanix v4 API sample scripts
3. **Use VS Code**: Open the API environment in Visual Studio Code for development

## Support

- Check `logs\` directory for detailed execution logs
- Review configuration files in `config\` directory
- Consult the full documentation in `docs\` directory

## What's Next?

- Explore the Nutanix v4 API environment: https://github.com/hardevsanghera/ntnx-v4api-cats
- Learn about VM deployment: https://github.com/hardevsanghera/deploy_win_vm_v1
- Customize configurations for your specific environment needs
# Auto-Windows: Advanced Usage Guide

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Configuration Management](#configuration-management)
- [Advanced Deployment Scenarios](#advanced-deployment-scenarios)
- [Customization and Extension](#customization-and-extension)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)
- [API Reference](#api-reference)

## Architecture Overview

### Two-Phase Design

Auto-Windows implements a two-phase deployment architecture:

```
┌─────────────────────────────────────────────────────────┐
│                    Auto-Windows                         │
├─────────────────────────┬───────────────────────────────┤
│       PHASE 1           │          PHASE 2              │
│   VM Deployment         │   API Environment Setup       │
├─────────────────────────┼───────────────────────────────┤
│ • Clone deploy_win_vm_v1│ • Download Install script     │
│ • Setup Python env      │ • Install PowerShell 7        │
│ • Resource selection    │ • Install Python 3.13+        │
│ • VM creation           │ • Install VS Code              │
│ • Sysprep customization │ • Install Git for Windows     │
│ • Deployment monitoring │ • Setup API repository        │
└─────────────────────────┴───────────────────────────────┘
```

### Component Interaction

```
Deploy-AutoWindows.ps1 (Master Orchestrator)
    ├── Phase1/
    │   ├── Initialize-VMDeployment.ps1
    │   ├── Get-ExternalRepo.ps1
    │   └── Invoke-VMDeployment.ps1
    ├── Phase2/
    │   ├── Initialize-APIEnvironment.ps1
    │   └── Install-NtnxEnvironment.ps1
    └── Config/
        ├── settings.json
        ├── deployment-config.json
        └── environment-config.json
```

## Configuration Management

### Configuration Hierarchy

1. **Global Settings** (`config/settings.json`)
   - Repository URLs and paths
   - Execution preferences
   - Logging configuration

2. **Deployment Configuration** (`config/deployment-config.json`)
   - Prism Central connection details
   - VM specifications
   - Deployment parameters

3. **Environment Configuration** (`config/environment-config.json`)
   - Component installation preferences
   - Installation paths
   - Post-installation tasks

### Environment-Specific Configurations

#### Development Environment
```json
{
  "prismCentral": {
    "ip": "192.168.1.100",
    "username": "dev-admin"
  },
  "vmConfiguration": {
    "namePrefix": "DEV-WIN-",
    "domain": {
      "join": true,
      "name": "dev.company.com"
    }
  }
}
```

#### Production Environment
```json
{
  "prismCentral": {
    "ip": "10.1.1.100", 
    "username": "prod-admin"
  },
  "vmConfiguration": {
    "namePrefix": "PROD-WIN-",
    "domain": {
      "join": true,
      "name": "prod.company.com"
    }
  }
}
```

### Configuration Templates

Use configuration templates for different scenarios:

```powershell
# Development template
.\Setup-Configuration.ps1 -Action Setup -ConfigType dev -Interactive

# Production template  
.\Setup-Configuration.ps1 -Action Setup -ConfigType prod -Interactive

# Full installation template
.\Setup-Configuration.ps1 -Action Setup -ConfigType full -Interactive

# Minimal installation template
.\Setup-Configuration.ps1 -Action Setup -ConfigType minimal -Interactive
```

## Advanced Deployment Scenarios

### Scenario 1: Batch VM Deployment

Deploy multiple VMs with different configurations:

```powershell
# Deploy development VMs
Copy-Item config\deployment-config.dev.json config\deployment-config.json
.\Deploy-AutoWindows.ps1 -Phase 1 -NonInteractive

# Deploy production VMs
Copy-Item config\deployment-config.prod.json config\deployment-config.json  
.\Deploy-AutoWindows.ps1 -Phase 1 -NonInteractive
```

### Scenario 2: Environment-Only Setup

Setup API environment without VM deployment:

```powershell
# Skip VM deployment, setup API environment only
.\Deploy-AutoWindows.ps1 -Phase 2 -NonInteractive
```

### Scenario 3: Custom Installation Paths

Specify custom installation paths:

```powershell
# Modify environment config for custom path
$config = Get-Content config\environment-config.json | ConvertFrom-Json
$config.environment.installPath = "D:\Development\Nutanix-API"
$config | ConvertTo-Json -Depth 10 | Set-Content config\environment-config.json

.\Deploy-AutoWindows.ps1 -Phase 2
```

### Scenario 4: Automated CI/CD Integration

Integrate with CI/CD pipelines:

```yaml
# Azure DevOps Pipeline Example
steps:
- task: PowerShell@2
  displayName: 'Deploy Auto-Windows Environment'
  inputs:
    targetType: 'filePath'
    filePath: 'Deploy-AutoWindows.ps1'
    arguments: '-Phase 2 -NonInteractive -SkipPrerequisites'
```

## Customization and Extension

### Adding Custom Components

Extend Phase 2 to install additional components:

1. **Modify Environment Configuration**:
```json
{
  "components": {
    "customTool": {
      "install": true,
      "downloadUrl": "https://example.com/tool.msi",
      "installArgs": "/S"
    }
  }
}
```

2. **Extend Installation Script**:
```powershell
# Add to Install-NtnxEnvironment.ps1
function Install-CustomTool {
    param([object]$Config)
    
    if ($Config.components.customTool.install) {
        # Custom installation logic
    }
}
```

### Custom Sysprep Templates

Create custom Windows sysprep templates:

1. **Add Custom Sysprep File**:
   - Place `sysprep-custom.xml` in VM deployment repository
   - Configure placeholders: `XXVMNAMEXX`, `XXPASSWORDXX`

2. **Update Deployment Configuration**:
```json
{
  "deployment": {
    "selectedResources": {
      "sysprepFile": "sysprep-custom.xml"
    }
  }
}
```

### Post-Deployment Scripts

Add custom post-deployment automation:

```powershell
# Create post-deployment.ps1
param([object]$DeploymentResults)

if ($DeploymentResults.Phase1.Success) {
    # Custom VM configuration
    Write-Host "VM deployed: $($DeploymentResults.Phase1.Results.VMUUID)"
}

if ($DeploymentResults.Phase2.Success) {
    # Custom environment setup
    Write-Host "Environment ready at: $($DeploymentResults.Phase2.Results.InstallPath)"
}
```

## Security Considerations

### Credential Management

**Never store passwords in configuration files**. Use secure alternatives:

1. **Environment Variables**:
```powershell
$env:PC_USERNAME = "admin"
$env:PC_PASSWORD = "secure-password"
```

2. **Azure Key Vault** (for Azure environments):
```powershell
$password = Get-AzKeyVaultSecret -VaultName "MyVault" -SecretName "PC-Password"
```

3. **Windows Credential Manager**:
```powershell
$cred = Get-StoredCredential -Target "PrismCentral"
```

### Network Security

1. **Use HTTPS**: Ensure Prism Central uses HTTPS (port 9440)
2. **Certificate Validation**: Enable certificate checking in production
3. **Network Isolation**: Deploy in isolated network segments
4. **Firewall Rules**: Configure appropriate firewall rules

### Access Control

1. **Least Privilege**: Use service accounts with minimal required permissions
2. **Role-Based Access**: Configure Nutanix roles appropriately
3. **Audit Logging**: Enable audit logging for all API operations
4. **Regular Rotation**: Rotate credentials regularly

## Troubleshooting

### Common Issues

#### Issue: PowerShell Execution Policy
```
Error: Execution of scripts is disabled on this system
```

**Solution**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Issue: Network Connectivity
```
Error: Cannot reach Prism Central at 10.1.1.100
```

**Solutions**:
1. Check network connectivity: `Test-NetConnection 10.1.1.100 -Port 9440`
2. Verify Prism Central IP address
3. Check firewall rules
4. Validate DNS resolution

#### Issue: Python Environment
```
Error: Python not found in PATH
```

**Solutions**:
1. Install Python manually: `winget install Python.Python.3.13`
2. Refresh PATH: `$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")`
3. Use Phase 2 to install Python automatically

#### Issue: Git Clone Failures
```
Error: Failed to clone repository
```

**Solutions**:
1. Check internet connectivity
2. Configure Git proxy if needed: `git config --global http.proxy http://proxy:port`
3. Use SSH keys for authentication if required

### Diagnostic Tools

#### Configuration Validation
```powershell
.\Setup-Configuration.ps1 -Action Validate
```

#### Connectivity Testing
```powershell
# Test Prism Central connectivity
Test-NetConnection <PC-IP> -Port 9440

# Test internet connectivity
Test-NetConnection github.com -Port 443
```

#### Component Verification
```powershell
# Check installed components
pwsh --version
python --version
code --version
git --version
```

### Log Analysis

#### Main Execution Log
```powershell
# View recent entries
Get-Content logs\deploy-auto-windows.log -Tail 100

# Search for errors
Select-String -Path logs\deploy-auto-windows.log -Pattern "ERROR"
```

#### Phase-Specific Logs
```powershell
# Phase 1 logs
Get-Content logs\phase1.log

# Phase 2 logs  
Get-Content logs\phase2.log
```

## API Reference

### Main Orchestration Script

#### Deploy-AutoWindows.ps1

**Parameters**:
- `-Phase`: Specify execution phase ("1", "2", "All")
- `-ConfigDirectory`: Configuration directory path
- `-WorkingDirectory`: Working directory for temporary files
- `-LogDirectory`: Log output directory
- `-SkipPrerequisites`: Skip prerequisite validation
- `-NonInteractive`: Run without user prompts

**Examples**:
```powershell
# Full deployment
.\Deploy-AutoWindows.ps1

# Phase 1 only in non-interactive mode
.\Deploy-AutoWindows.ps1 -Phase 1 -NonInteractive

# Custom directories
.\Deploy-AutoWindows.ps1 -ConfigDirectory "my-config" -WorkingDirectory "my-temp"
```

### Configuration Management

#### Setup-Configuration.ps1

**Parameters**:
- `-Action`: Action to perform ("Setup", "Validate", "Test", "Reset")
- `-ConfigType`: Configuration template ("dev", "prod", "full", "minimal", "custom")
- `-Interactive`: Enable interactive mode

**Examples**:
```powershell
# Interactive setup
.\Setup-Configuration.ps1 -Action Setup -Interactive

# Validate configuration
.\Setup-Configuration.ps1 -Action Validate -ConfigType prod

# Reset to defaults
.\Setup-Configuration.ps1 -Action Reset
```

### Return Objects

#### Phase 1 Results
```powershell
@{
    Success = $true
    VMName = "DEV-WIN-1021-1430"
    VMUUID = "12345678-1234-5678-9abc-123456789def"
    TaskUUID = "87654321-4321-8765-cba9-876543210fed"
    DeploymentTime = [DateTime]
}
```

#### Phase 2 Results
```powershell
@{
    Success = $true
    ValidationResults = @{
        PowerShell7 = $true
        Python = $true
        VSCode = $true
        Git = $true
        Repository = $true
        OverallSuccess = $true
    }
    Summary = "Installation completed successfully"
}
```

### Configuration Schema

#### Global Settings Schema
```json
{
  "global": {
    "workingDirectory": "string",
    "logDirectory": "string", 
    "maxLogAgeDays": "number"
  },
  "repositories": {
    "vmDeployment": {
      "url": "string",
      "localPath": "string",
      "branch": "string"
    },
    "apiEnvironment": {
      "url": "string",
      "scriptUrl": "string",
      "localPath": "string"
    }
  },
  "execution": {
    "autoMode": "boolean",
    "phase1": { "enabled": "boolean" },
    "phase2": { "enabled": "boolean" }
  }
}
```

#### Deployment Configuration Schema
```json
{
  "prismCentral": {
    "ip": "string",
    "username": "string", 
    "password": "string",
    "port": "number"
  },
  "vmConfiguration": {
    "namePrefix": "string",
    "adminPassword": "string",
    "domain": {
      "join": "boolean",
      "name": "string",
      "username": "string",
      "password": "string"
    }
  },
  "deployment": {
    "mode": "string",
    "autoSelectResources": "boolean"
  }
}
```

## Best Practices

### Development Workflow

1. **Start with Templates**: Use provided configuration templates
2. **Validate Early**: Run validation before deployment
3. **Test Incrementally**: Test phases independently
4. **Monitor Logs**: Always check logs for issues
5. **Version Control**: Track configuration changes

### Production Deployment

1. **Security First**: Never store passwords in files
2. **Test Thoroughly**: Test in development before production
3. **Backup Configurations**: Maintain configuration backups
4. **Audit Trail**: Enable comprehensive logging
5. **Change Management**: Follow change management processes

### Maintenance

1. **Regular Updates**: Keep external repositories updated
2. **Log Rotation**: Implement log rotation policies
3. **Health Checks**: Regular environment health checks
4. **Documentation**: Keep deployment documentation current
5. **Disaster Recovery**: Plan for failure scenarios
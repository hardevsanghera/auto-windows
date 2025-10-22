# Auto-Windows Configuration Guide

This directory contains configuration files and templates for Auto-Windows deployment scenarios with enhanced automation features.

## 📁 Configuration Files

### settings.json
Global settings for the Auto-Windows deployment process:
- Repository URLs and local paths
- Execution preferences and automation settings
- Logging configuration and retention
- Default timeouts and retry parameters

### deployment-config.json  
VM deployment configuration for Phase 1:
- Prism Central connection details (IP, port, credentials)
- VM specifications and naming conventions
- Network and cluster preferences
- Deployment monitoring and validation settings

### environment-config.json
API environment setup configuration for Phase 2:
- Component installation preferences (PowerShell, Python, VS Code, Git)
- Installation paths and directory structure
- HTTPS/SSL configuration for secure connections
- Post-installation tasks and validation settings

## 🚀 Usage Examples

### Complete Automated Deployment
```powershell
# Run full end-to-end deployment with intelligent automation
.\Deploy-AutoWindows.ps1 -Phase All
```

### Phase-Specific Execution  
```powershell
# Run only VM deployment (Phase 1)
.\Deploy-AutoWindows.ps1 -Phase 1

# Run API environment setup with automatic IP discovery
.\Deploy-AutoWindows.ps1 -Phase 2

# Setup API environment on specific VM with HTTPS (default)
.\Setup-Phase2-ApiEnvironment.ps1 -VMIPAddress 10.38.19.22

# Force HTTP if needed
.\Setup-Phase2-ApiEnvironment.ps1 -VMIPAddress 10.38.19.22 -UseHTTPS:$false
```

### Advanced Configuration and Testing
```powershell
# Test VM readiness with comprehensive assessment
.\Test-VMReadiness.ps1 -VMIPAddress 10.38.19.22 -TestLevel Full -AddToTrusted

# Manual IP discovery with extended timeout
.\Get-VMIPAddress.ps1 -MaxRetries 15 -RetryDelay 60

# Use custom configuration directory
.\Deploy-AutoWindows.ps1 -ConfigDirectory "environments\production"

# Non-interactive mode for CI/CD
.\Deploy-AutoWindows.ps1 -NonInteractive -SkipPrerequisites
```

## ⚙️ Configuration Templates

### Development Environment (config/deployment-config.dev.json)
```json
{
  "prismCentral": {
    "ip": "192.168.1.100",
    "port": 9440,
    "useHTTPS": true,
    "username": "dev-admin"
  },
  "vmConfiguration": {
    "namePrefix": "DEV-WIN-",
    "adminPassword": "DevPassword123!",
    "domain": {
      "join": true,
      "name": "dev.company.com"
    }
  },
  "security": {
    "useHTTPS": true,
    "allowSelfSignedCerts": true,
    "skipCertificateValidation": true
  }
}
```

### Production Environment (config/deployment-config.prod.json)
```json
{
  "prismCentral": {
    "ip": "10.1.1.100",
    "port": 9440,
    "useHTTPS": true,
    "username": "prod-admin"
  },
  "vmConfiguration": {
    "namePrefix": "PROD-WIN-",
    "domain": {
      "join": true,
      "name": "prod.company.com"
    }
  },
  "security": {
    "useHTTPS": true,
    "enforceStrictSSL": true,
    "allowSelfSignedCerts": false
  }
}
```

## 🔒 Security Configuration

### HTTPS and SSL Settings
Auto-Windows now defaults to HTTPS connectivity with comprehensive SSL bypass for lab environments:

```json
{
  "security": {
    "useHTTPS": true,
    "defaultPort": 5986,
    "sslBypass": {
      "skipCACheck": true,
      "skipCNCheck": true,
      "skipRevocationCheck": true
    },
    "autoConfigureHTTPS": true,
    "fallbackToHTTP": false
  }
}
```

### Credential Management
**Best Practices for secure credential handling:**

1. **Environment Variables** (Recommended):
```powershell
$env:PC_USERNAME = "admin"
$env:PC_PASSWORD = "secure-password"
$env:VM_ADMIN_PASSWORD = "vm-password"
```

2. **Clear Password Cache**:
```powershell
# Clear cached passwords when needed
.\Deploy-AutoWindows.ps1 -DelPw
```

3. **Azure Key Vault Integration**:
```powershell
$cred = Get-AzKeyVaultSecret -VaultName "MyVault" -SecretName "PC-Credentials"
```

## 🛠️ Customization Guide

### 1. Copy Configuration Templates
```powershell
# Development environment
Copy-Item config\deployment-config.dev.json config\deployment-config.json

# Production environment
Copy-Item config\deployment-config.prod.json config\deployment-config.json
```

### 2. Edit Configuration Files
Update the JSON files with your specific settings:
- **Prism Central**: IP addresses, ports, and authentication
- **VM Configuration**: Naming conventions, passwords, domain settings
- **Network Settings**: Cluster preferences, VLAN configurations
- **Security**: HTTPS preferences, certificate handling
- **Automation**: Timeout values, retry parameters

### 3. Advanced Customization
```json
{
  "automation": {
    "ipDiscovery": {
      "maxRetries": 10,
      "retryDelay": 30,
      "timeoutMinutes": 15
    },
    "vmReadiness": {
      "testLevel": "Full",
      "addToTrusted": true,
      "configureHTTPS": true
    },
    "phase2Setup": {
      "useHTTPS": true,
      "customInstallPath": "C:\\Dev\\ntnx-v4api-cats",
      "installComponents": {
        "powerShell7": true,
        "python313": true,
        "vsCode": true,
        "git": true,
        "extensions": ["ms-vscode.powershell", "ms-python.python"]
      }
    }
  }
}
```

## ✅ Configuration Validation

### Automated Validation
```powershell
# Validate configuration before deployment
.\Setup-Configuration.ps1 -Action Validate

# Test connectivity and prerequisites
.\Setup-Configuration.ps1 -Action Test -ConfigType dev
```

### Manual Validation Checklist
- [ ] Prism Central IP address and port accessibility
- [ ] Valid credentials for Prism Central
- [ ] VM administrator password meets complexity requirements
- [ ] Network and cluster names exist in environment
- [ ] Domain join credentials (if applicable)
- [ ] Installation paths are accessible
- [ ] Required ports are open (5985/5986 for WinRM)

## 🔍 Configuration Schema Reference

### Deployment Configuration (deployment-config.json)
```json
{
  "prismCentral": {
    "ip": "string (required)",
    "port": "number (default: 9440)",
    "useHTTPS": "boolean (default: true)",
    "username": "string (required)",
    "password": "string (optional - use env vars)"
  },
  "vmConfiguration": {
    "namePrefix": "string (default: WIN-)",
    "adminPassword": "string (required)",
    "domain": {
      "join": "boolean (default: false)",
      "name": "string (optional)",
      "username": "string (optional)",
      "password": "string (optional)"
    }
  },
  "deployment": {
    "mode": "string (auto/interactive)",
    "autoSelectResources": "boolean (default: false)",
    "monitoring": {
      "enabled": "boolean (default: true)",
      "interval": "number (default: 30)"
    }
  }
}
```

### Environment Configuration (environment-config.json)
```json
{
  "environment": {
    "installPath": "string (default: C:\\Dev\\ntnx-v4api-cats)",
    "components": {
      "powerShell7": "boolean (default: true)",
      "python": "boolean (default: true)",
      "vsCode": "boolean (default: true)",
      "git": "boolean (default: true)"
    },
    "connectivity": {
      "useHTTPS": "boolean (default: true)",
      "port": "number (default: 5986)",
      "sessionOptions": {
        "skipCACheck": "boolean (default: true)",
        "skipCNCheck": "boolean (default: true)",
        "skipRevocationCheck": "boolean (default: true)"
      }
    }
  }
}
```

## 🚨 Security Best Practices

### Production Environments
- **Never store passwords** in configuration files
- **Use proper SSL certificates** instead of self-signed
- **Enable certificate validation** in production
- **Implement least-privilege access** for service accounts
- **Regular credential rotation** and audit logging

### Development Environments
- **Self-signed certificates** are acceptable for lab use
- **SSL bypass options** can be enabled for testing
- **Password policies** should still be enforced
- **Network isolation** from production systems

## 📊 Monitoring and Logging

### Log Configuration
```json
{
  "logging": {
    "enabled": true,
    "directory": "logs",
    "maxAgeDays": 30,
    "levels": ["Info", "Warning", "Error"],
    "includeTimestamps": true,
    "separatePhaseLog": true
  }
}
```

### Available Logs
- `deploy-auto-windows.log` - Main execution log
- `phase1.log` - VM deployment detailed log
- `phase2.log` - API environment setup detailed log
- `ip-discovery.log` - IP discovery and waiting log
- `vm-readiness.log` - VM testing and validation log

## 🆘 Troubleshooting Configuration

### Common Configuration Issues

1. **Invalid JSON Syntax**:
```powershell
# Validate JSON syntax
Get-Content config\deployment-config.json | ConvertFrom-Json
```

2. **Missing Required Fields**:
```powershell
# Run configuration validation
.\Setup-Configuration.ps1 -Action Validate
```

3. **Network Connectivity**:
```powershell
# Test Prism Central connectivity
Test-NetConnection 10.1.1.100 -Port 9440
```

4. **PowerShell Remoting**:
```powershell
# Test WinRM connectivity
Test-NetConnection <VM-IP> -Port 5986
.\Test-VMReadiness.ps1 -VMIPAddress <VM-IP> -TestLevel Full
```

## 🔗 Related Documentation

- **[Main README](../README.md)** - Overview and getting started
- **[Quick Start Guide](../docs/QUICKSTART.md)** - 5-minute deployment
- **[Advanced Usage](../docs/ADVANCED.md)** - Comprehensive configuration
- **[Examples](../docs/EXAMPLES.md)** - Real-world scenarios

---

## 📞 Support

For configuration assistance:
1. Check the validation output: `.\Setup-Configuration.ps1 -Action Validate`
2. Review logs in the `logs\` directory
3. Test connectivity using provided diagnostic tools
4. Refer to examples in `docs\EXAMPLES.md`
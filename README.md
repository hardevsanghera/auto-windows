# Auto-Windows: Two-Phase VM Deployment and API Environment Setup

## Overview

Auto-Windows provides a complete two-phase automation solution for deploying Windows VMs and setting up Nutanix v4 API development environments. This system combines the power of two external repositories to create a seamless deployment experience.

### What Auto-Windows Does

1. **PHASE 1**: Deploy Windows VMs using the [`deploy_win_vm_v1`](https://github.com/hardevsanghera/deploy_win_vm_v1) repository
2. **PHASE 2**: Set up Nutanix v4 API environment using the [`ntnx-v4api-cats`](https://github.com/hardevsanghera/ntnx-v4api-cats) experimental script

## Quick Start (5 minutes)

```powershell
# 1. Clone and setup
git clone https://github.com/hardevsanghera/auto-windows.git
cd auto-windows

# 2. Interactive configuration
.\Setup-Configuration.ps1 -Action Setup -Interactive

# 3. Deploy everything
.\Deploy-AutoWindows.ps1
```

## Architecture

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

## Repository Structure

```
auto-windows/
├── README.md                        # This file
├── Deploy-AutoWindows.ps1           # Master orchestration script
├── Setup-Configuration.ps1          # Configuration helper tool
├── config/                          # Configuration files
│   ├── settings.json               # Global settings
│   ├── deployment-config.json      # VM deployment configuration
│   ├── environment-config.json     # API environment configuration
│   ├── deployment-config.dev.json  # Development template
│   ├── deployment-config.prod.json # Production template
│   ├── environment-config.full.json # Full installation template
│   ├── environment-config.minimal.json # Minimal template
│   └── README.md                   # Configuration documentation
├── phase1/                         # Phase 1: VM Deployment
│   ├── Initialize-VMDeployment.ps1 # Main Phase 1 script
│   ├── Get-ExternalRepo.ps1        # Repository management
│   └── Invoke-VMDeployment.ps1     # VM deployment wrapper
├── phase2/                         # Phase 2: API Environment
│   ├── Initialize-APIEnvironment.ps1 # Main Phase 2 script
│   └── Install-NtnxEnvironment.ps1   # Environment setup wrapper
├── docs/                           # Documentation
│   ├── QUICKSTART.md              # Quick start guide
│   ├── ADVANCED.md                # Advanced usage
│   └── EXAMPLES.md                # Usage examples
├── logs/                          # Execution logs (created during run)
└── temp/                          # Temporary files (created during run)
```

## Prerequisites

- **Windows OS** (Windows 10/11, Windows Server 2019/2022)
- **PowerShell 5.1+** (PowerShell 7+ recommended)
- **Internet connectivity** (to download external repositories)
- **Nutanix Prism Central access** (for Phase 1 VM deployment)
- **Administrative privileges** (recommended for Phase 2 installations)

## Configuration Options

Auto-Windows supports multiple configuration approaches:

### Interactive Setup (Recommended for first-time users)
```powershell
.\Setup-Configuration.ps1 -Action Setup -Interactive
```

### Template-based Setup
```powershell
# Development environment
.\Setup-Configuration.ps1 -Action Setup -ConfigType dev -Interactive

# Production environment  
.\Setup-Configuration.ps1 -Action Setup -ConfigType prod -Interactive

# Full installation (all components)
.\Setup-Configuration.ps1 -Action Setup -ConfigType full -Interactive

# Minimal installation (essential components only)
.\Setup-Configuration.ps1 -Action Setup -ConfigType minimal -Interactive
```

### Manual Configuration
Edit configuration files directly:
- `config/deployment-config.json` - VM deployment settings
- `config/environment-config.json` - API environment settings
- `config/settings.json` - Global settings

## Usage Examples

### Complete Deployment
```powershell
# Deploy VM and setup API environment
.\Deploy-AutoWindows.ps1
```

### Phase-Specific Deployment
```powershell
# VM deployment only
.\Deploy-AutoWindows.ps1 -Phase 1

# API environment setup only
.\Deploy-AutoWindows.ps1 -Phase 2
```

### Non-Interactive Mode
```powershell
# Automated deployment (for CI/CD)
.\Deploy-AutoWindows.ps1 -NonInteractive
```

### Custom Configuration
```powershell
# Use custom configuration directory
.\Deploy-AutoWindows.ps1 -ConfigDirectory "my-configs"
```

## What Gets Deployed

### Phase 1: Windows VM Deployment
- **VM Creation**: Deploys Windows VMs to Nutanix AHV clusters
- **Resource Selection**: Interactive selection of clusters, networks, images
- **Customization**: Sysprep-based Windows customization
- **Monitoring**: Deployment progress tracking
- **Integration**: Uses Nutanix v3.1 REST API via Python

### Phase 2: Nutanix v4 API Environment
- **PowerShell 7**: Latest PowerShell for cross-platform scripting
- **Python 3.13+**: Python environment with virtual environment setup
- **Visual Studio Code**: IDE with Nutanix-specific extensions
- **Git for Windows**: Version control and repository management
- **API Repository**: Complete Nutanix v4 API development environment
- **Documentation**: Ready-to-use API examples and documentation

## Validation and Testing

### Configuration Validation
```powershell
# Validate configuration before deployment
.\Setup-Configuration.ps1 -Action Validate

# Test connectivity and settings
.\Setup-Configuration.ps1 -Action Test
```

### Deployment Verification
- Automatic component validation after installation
- Connectivity testing to Nutanix Prism Central
- Environment health checks
- Comprehensive logging and reporting

## Security Features

- **No Password Storage**: Passwords not stored in configuration files
- **Secure Input**: Hidden password prompts during interactive setup
- **Environment Variables**: Support for secure credential management
- **Audit Logging**: Comprehensive logging for compliance and troubleshooting

## Troubleshooting

### Quick Diagnostics
```powershell
# Check logs for errors
Get-Content logs\deploy-auto-windows.log -Tail 50

# Validate configuration
.\Setup-Configuration.ps1 -Action Validate

# Reset configuration to defaults
.\Setup-Configuration.ps1 -Action Reset
```

### Common Issues
- **Network Connectivity**: Ensure access to Prism Central and internet
- **Permissions**: Run with administrative privileges for Phase 2
- **Prerequisites**: Verify PowerShell version and Windows compatibility
- **Configuration**: Validate all required fields are populated

## Documentation

- **[Quick Start Guide](docs/QUICKSTART.md)** - Get up and running in 5 minutes
- **[Advanced Usage](docs/ADVANCED.md)** - Comprehensive configuration and customization
- **[Usage Examples](docs/EXAMPLES.md)** - Real-world deployment scenarios
- **[Configuration Guide](config/README.md)** - Detailed configuration options

## Integration

Auto-Windows integrates seamlessly with:
- **CI/CD Pipelines** (Azure DevOps, GitHub Actions)
- **Infrastructure as Code** (Terraform, PowerShell DSC)
- **Configuration Management** (Ansible, Chef, Puppet)
- **Monitoring Systems** (SCOM, Nagios, Zabbix)

## Source Repositories

Auto-Windows leverages these external repositories:
- **VM Deployment**: [deploy_win_vm_v1](https://github.com/hardevsanghera/deploy_win_vm_v1) - Python-based Windows VM deployment
- **API Environment**: [ntnx-v4api-cats](https://github.com/hardevsanghera/ntnx-v4api-cats) - Nutanix v4 API development environment

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is provided "AS IS" for educational and development purposes. See individual source repositories for their specific licenses.

## Author

**Hardev Sanghera** - [hardev@nutanix.com](mailto:hardev@nutanix.com)

*October 2025*

---

## Support

- **Documentation**: Check the `docs/` directory for comprehensive guides
- **Logs**: Review logs in the `logs/` directory for troubleshooting
- **Configuration**: Use `Setup-Configuration.ps1` for guided setup and validation
- **Issues**: Report issues through the repository's issue tracking system
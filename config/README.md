# Auto-Windows Configuration Examples

This directory contains example configurations for different deployment scenarios.

## Configuration Files

### settings.json
Global settings for the Auto-Windows deployment process:
- Repository URLs and local paths
- Execution preferences
- Logging configuration

### deployment-config.json  
VM deployment configuration for Phase 1:
- Prism Central connection details
- VM specifications
- Deployment preferences
- Monitoring settings

### environment-config.json
API environment setup configuration for Phase 2:
- Component installation preferences
- Installation paths
- Post-installation tasks
- Validation settings

## Usage Examples

### Basic Deployment
```powershell
# Run complete deployment with default settings
.\Deploy-AutoWindows.ps1
```

### Phase-Specific Execution  
```powershell
# Run only VM deployment (Phase 1)
.\Deploy-AutoWindows.ps1 -Phase 1

# Run only API environment setup (Phase 2)
.\Deploy-AutoWindows.ps1 -Phase 2
```

### Custom Configuration
```powershell
# Use custom configuration directory
.\Deploy-AutoWindows.ps1 -ConfigDirectory "my-configs"

# Non-interactive mode
.\Deploy-AutoWindows.ps1 -NonInteractive
```

## Customization

1. **Copy** the example configurations to your environment
2. **Edit** the JSON files with your specific settings:
   - Prism Central IP addresses and credentials
   - VM naming conventions
   - Installation paths
   - Component preferences
3. **Run** the deployment with your custom configuration

## Security Notes

- **Never commit passwords** to version control
- Use environment variables or secure vaults for sensitive data
- Review all configuration files before deployment
- Test in a development environment first

## Validation

The deployment scripts include validation for:
- Configuration file syntax
- Required parameters
- Network connectivity
- Component availability
- Installation success
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Get IP address of deployed VM from Nutanix Prism Central

.DESCRIPTION
    Queries the Nutanix Prism Central API to get the IP address of the most recently deployed VM.
         Write-Host "[INFO] Opening Prism Central web interface for manual VM check..." -ForegroundColor Cyan
        Start-Process "https://$(Get-PrismCentralIP):9440" Uses the cached admin password if available.

.PARAMETER VMName
    Specific VM name to query (optional - defaults to latest deployed VM)

.PARAMETER VMUUID
    Specific VM UUID to query (optional - defaults to latest deployed VM)

.EXAMPLE
    .\Get-VMIPAddress.ps1
    
.EXAMPLE
    .\Get-VMIPAddress.ps1 -VMName "HARDEV-1021"
    
.EXAMPLE
    .\Get-VMIPAddress.ps1 -VMUUID "44fee51f-5424-4752-8b66-e74e1ef317ab"
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$VMName,
    
    [Parameter(Mandatory = $false)]
    [string]$VMUUID,
    
    [Parameter(Mandatory = $false)]
    [int]$MaxRetries = 5,
    
    [Parameter(Mandatory = $false)]
    [int]$RetryDelay = 30
)

# Import password manager
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Get-PrismCentralIP {
    <#
    .SYNOPSIS
    Get Prism Central IP address from configuration
    
    .OUTPUTS
    Returns Prism Central IP address
    #>
    try {
        $configPath = Join-Path $scriptRoot "config\deployment-config.json"
        if (Test-Path $configPath) {
            $config = Get-Content $configPath | ConvertFrom-Json
            return $config.prismCentral.ip
        }
        else {
            Write-Warning "Configuration file not found: $configPath"
            return "10.38.10.138"  # Fallback default
        }
    }
    catch {
        Write-Warning "Failed to read Prism Central IP from config: $($_.Exception.Message)"
        return "10.38.10.138"  # Fallback default
    }
}

Import-Module (Join-Path $scriptRoot "PasswordManager.ps1") -Force

function Get-VMIPFromPrismCentral {
    param(
        [string]$PCHost = (Get-PrismCentralIP),
        [string]$Username = "admin",
        [string]$Password,
        [string]$VMUUID
    )
    
    try {
        Write-Host "DEBUG: Get-VMIPFromPrismCentral called with Username: '$Username', Password: '$Password' (Length: $($Password.Length))" -ForegroundColor Magenta
        $base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Username`:$Password"))
        Write-Host "DEBUG: Created base64Auth: '$base64Auth'" -ForegroundColor Magenta
        $headers = @{
            "Authorization" = "Basic $base64Auth"
            "Content-Type" = "application/json"
            "Accept" = "application/json"
        }
        
        $uri = "https://$PCHost`:9440/api/nutanix/v3/vms/$VMUUID"
        Write-Host "DEBUG: Making API call to: $uri" -ForegroundColor Magenta
        
        Write-Host "[INFO] Querying VM details..." -ForegroundColor Cyan
        
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -SkipCertificateCheck -ErrorAction Stop
        
        $vmName = $response.spec.name
        $powerState = $response.spec.resources.power_state
        
        Write-Host "[OK] VM Name: $vmName" -ForegroundColor Green
        Write-Host "[OK] Power State: $powerState" -ForegroundColor Green
        
        # Check network interfaces - IP addresses are in status.resources, not spec.resources
        $nicList = $response.status.resources.nic_list
        
        Write-Host "DEBUG: Raw nic_list data: $($nicList | ConvertTo-Json -Depth 3)" -ForegroundColor Magenta
        
        if (-not $nicList -or $nicList.Count -eq 0) {
            Write-Host "[WARN] No network interfaces found in status.resources.nic_list" -ForegroundColor Yellow
            Write-Host "DEBUG: VM may still be initializing. Checking spec.resources.nic_list..." -ForegroundColor Magenta
            
            # Check if NICs are defined in spec but not yet populated in status
            $specNicList = $response.spec.resources.nic_list
            if ($specNicList -and $specNicList.Count -gt 0) {
                Write-Host "[INFO] Found $($specNicList.Count) network interface(s) defined in spec, but not yet active in status" -ForegroundColor Yellow
                Write-Host "[INFO] VM may still be booting. Network interfaces should appear shortly." -ForegroundColor Yellow
            }
            
            return $null
        }
        
        # Look for IP addresses
        $ipAddresses = @()
        
        for ($i = 0; $i -lt $nicList.Count; $i++) {
            $nic = $nicList[$i]
            Write-Host "`n[INFO] Network Interface $($i + 1):" -ForegroundColor Cyan
            
            $nicHasIP = $false
            if ($nic.PSObject.Properties['ip_endpoint_list']) {
                foreach ($endpoint in $nic.ip_endpoint_list) {
                    $ip = $endpoint.ip
                    $ipType = $endpoint.type
                    
                    if ($ip -and $ip -ne "Not assigned") {
                        Write-Host "  IP Address: $ip (Type: $ipType)" -ForegroundColor Green
                        $ipAddresses += $ip
                        $nicHasIP = $true
                    }
                }
            }
            
            if (-not $nicHasIP) {
                Write-Host "  IP Address: Not yet assigned" -ForegroundColor Yellow
            }
            
            # Show subnet info
            if ($nic.subnet_reference) {
                Write-Host "  Subnet UUID: $($nic.subnet_reference.uuid)" -ForegroundColor Gray
            }
        }
        
        # Return both IP addresses and VM name
        return @{
            IPAddresses = $ipAddresses
            VMName = $vmName
        }
        
    } catch {
        $errorResponse = $_.ErrorDetails.Message
        Write-Host "[ERROR] Failed to query VM: $($_.Exception.Message)" -ForegroundColor Red
        
        if ($_.Exception.Response.StatusCode -eq 401) {
            if ($errorResponse -and $errorResponse.Contains("locked out")) {
                Write-Host "[ERROR] User account is locked out. Please wait 5-10 minutes for automatic unlock." -ForegroundColor Red
                Write-Host "[INFO] Alternatively, unlock the account in Prism Central or use a different user." -ForegroundColor Yellow
                return "LOCKED"
            } else {
                Write-Host "[ERROR] Authentication failed. Please check your password." -ForegroundColor Red
            }
        } elseif ($_.Exception.Response.StatusCode -eq 404) {
            Write-Host "[ERROR] VM not found. Please check the VM UUID." -ForegroundColor Red
        }
        
        if ($errorResponse) {
            Write-Host "[DEBUG] API Response: $errorResponse" -ForegroundColor Gray
        }
        return $null
    }
}

function Get-LatestVMInfo {
    $resultsFile = Join-Path $scriptRoot "temp\phase1-results.json"
    
    if (-not (Test-Path $resultsFile)) {
        Write-Host "[ERROR] No deployment results found. Please run deployment first." -ForegroundColor Red
        return $null
    }
    
    try {
        $results = Get-Content $resultsFile | ConvertFrom-Json
        return @{
            VMUUID = $results.VMUUID
            VMName = $results.VMName
            TaskUUID = $results.TaskUUID
        }
    } catch {
        Write-Host "[ERROR] Could not read deployment results: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Main execution
Write-Host ("=" * 60)
Write-Host "   GET VM IP ADDRESS FROM PRISM CENTRAL" -ForegroundColor Cyan
Write-Host ("=" * 60)

# Determine VM to query
$targetVMUUID = $VMUUID
$targetVMName = $VMName

if (-not $targetVMUUID) {
    if ($targetVMName) {
        Write-Host "[INFO] Searching for VM by name: $targetVMName" -ForegroundColor Cyan
        # Would need additional API call to search by name - for now use latest
    }
    
    # Get latest VM info
    $vmInfo = Get-LatestVMInfo
    if (-not $vmInfo) {
        exit 1
    }
    
    $targetVMUUID = $vmInfo.VMUUID
    $targetVMName = $vmInfo.VMName
}

Write-Host "[INFO] Target VM: $targetVMName" -ForegroundColor Cyan
Write-Host "[INFO] VM UUID: $targetVMUUID" -ForegroundColor Cyan

# Get password - try cached first, then prompt if authentication fails
$password = Get-CachedPassword -Username "admin"
$usingCachedPassword = $false

if ($password) {
    Write-Host "✓ Found cached password for: admin" -ForegroundColor Green
    $usingCachedPassword = $true
    # Convert SecureString to plain text for API use
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
    Write-Host "DEBUG: Using cached password (converted): '$plainPassword' (Length: $($plainPassword.Length))" -ForegroundColor Magenta
    $password = $plainPassword
} else {
    Write-Host "[INFO] No cached password found. Please enter password." -ForegroundColor Yellow
    $securePassword = Read-Host "Enter password for admin" -AsSecureString
    $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
    Write-Host "DEBUG: Using manually entered password: '$password' (Length: $($password.Length))" -ForegroundColor Magenta
}

# Query IP with retries
$attempt = 1
$ipAddresses = @()
$authRetried = $false

do {
    Write-Host "`n[ATTEMPT $attempt/$MaxRetries] Checking for IP address..." -ForegroundColor Cyan
    
    $result = Get-VMIPFromPrismCentral -VMUUID $targetVMUUID -Password $password
    
    if ($result -and $result.IPAddresses) {
        $ipAddresses = $result.IPAddresses
        if ($result.VMName -and -not $targetVMName) {
            $targetVMName = $result.VMName
        }
    } else {
        $ipAddresses = $null
    }
    
    # Check if user is locked out
    if ($ipAddresses -eq "LOCKED") {
        Write-Host "`n[ERROR] Cannot proceed - admin account is locked out." -ForegroundColor Red
        Write-Host "[INFO] Please wait 5-10 minutes for automatic unlock, or:" -ForegroundColor Yellow
        Write-Host "  1. Use Prism Central web interface to unlock the account" -ForegroundColor Gray
        Write-Host "  2. Contact your Nutanix administrator" -ForegroundColor Gray
        Write-Host "  3. Use an alternative admin account" -ForegroundColor Gray
        Write-Host "`n[INFO] Opening Prism Central web interface for manual VM check..." -ForegroundColor Cyan
        Start-Process "https://10.38.19.9:9440"
        exit 1
    }
    
    # If authentication failed and we haven't retried auth yet
    if ($null -eq $ipAddresses -and $usingCachedPassword -and -not $authRetried) {
        Write-Host "[WARN] Cached password may be incorrect. Please enter password manually." -ForegroundColor Yellow
        $securePassword = Read-Host "Enter password for admin" -AsSecureString
        $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
        $usingCachedPassword = $false
        $authRetried = $true
        
        # Try again with manual password
        Write-Host "[INFO] Retrying with manual password..." -ForegroundColor Cyan
        $result = Get-VMIPFromPrismCentral -VMUUID $targetVMUUID -Password $password
        
        if ($result -and $result.IPAddresses) {
            $ipAddresses = $result.IPAddresses
            if ($result.VMName -and -not $targetVMName) {
                $targetVMName = $result.VMName
            }
        } else {
            $ipAddresses = $null
        }
    }
    
    if ($ipAddresses -and $ipAddresses.Count -gt 0) {
        break
    }
    
    if ($attempt -lt $MaxRetries) {
        Write-Host "[INFO] No IP found yet. Waiting $RetryDelay seconds before retry..." -ForegroundColor Yellow
        Start-Sleep -Seconds $RetryDelay
    }
    
    $attempt++
    
} while ($attempt -le $MaxRetries)

# Display results
Write-Host "`n" + ("=" * 60)

if ($ipAddresses -and $ipAddresses.Count -gt 0) {
    # Use Select-Object to get the first item to avoid indexing issues
    $primaryIP = $ipAddresses | Select-Object -First 1
    
    Write-Host "🎯 VM IP ADDRESS FOUND!" -ForegroundColor Green
    Write-Host "   VM Name: $targetVMName" -ForegroundColor White
    Write-Host "   IP Address: $primaryIP" -ForegroundColor Green
    
    if ($ipAddresses.Count -gt 1) {
        Write-Host "   Additional IPs: $($ipAddresses[1..($ipAddresses.Count-1)] -join ', ')" -ForegroundColor Gray
    }
    
    Write-Host "`n💡 Connection Options:" -ForegroundColor Cyan
    Write-Host "   RDP: mstsc /v:$primaryIP" -ForegroundColor White
    Write-Host "   SSH: ssh Administrator@$primaryIP" -ForegroundColor White
    Write-Host "   PowerShell: Enter-PSSession -ComputerName $primaryIP -Credential Administrator" -ForegroundColor White
    
    # Return the primary IP address for the calling script
    return $primaryIP
    
} else {
    Write-Host "⏳ VM IP ADDRESS NOT AVAILABLE YET" -ForegroundColor Yellow
    Write-Host "   VM Name: $targetVMName" -ForegroundColor White
    Write-Host "   Status: VM is powered on but no IP assigned" -ForegroundColor Yellow
    Write-Host "`n💡 This is normal for new VMs. Common reasons:" -ForegroundColor Cyan
    Write-Host "   • VM is still booting (Windows can take 5-10 minutes)" -ForegroundColor Gray
    Write-Host "   • DHCP server hasn't assigned an IP yet" -ForegroundColor Gray
    Write-Host "   • Network drivers are installing" -ForegroundColor Gray
    Write-Host "   • Windows updates are running" -ForegroundColor Gray
    Write-Host "`n   Try again in a few minutes or check Prism Central web interface." -ForegroundColor White
    Write-Host "`n💻 Manual Check Options:" -ForegroundColor Cyan
    Write-Host "   • Web: https://$(Get-PrismCentralIP):9440 → VMs → HARDEV-1021" -ForegroundColor Gray
    Write-Host "   • CLI: ncli vm list name=$targetVMName" -ForegroundColor Gray
    
    # Return null to indicate no IP found
    return $null
}

Write-Host ("=" * 60)
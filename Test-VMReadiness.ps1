#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test VM readiness for PowerShell remoting and Phase 2 preparation

.DESCRIPTION
    Comprehensive test to determine if the deployed Windows VM is ready to accept
    PowerShell commands and can be prepared for Nutanix v4 API work in Phase 2.

.PARAMETER VMIPAddress
    IP address of the target VM to test

.PARAMETER VMCredential
    Credentials for the VM (defaults to Administrator)

.PARAMETER TestLevel
    Level of testing: Basic, Standard, Full
    - Basic: Network connectivity and basic PowerShell
    - Standard: Includes Windows features and API prerequisites  
    - Full: Complete Phase 2 readiness assessment

.EXAMPLE
    .\Test-VMReadiness.ps1 -VMIPAddress 10.38.19.26
    
.EXAMPLE
    .\Test-VMReadiness.ps1 -VMIPAddress 10.38.19.26 -TestLevel Full
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$VMIPAddress = "10.38.19.26",
    
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$VMCredential,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Basic", "Standard", "Full")]
    [string]$TestLevel = "Standard"
)

# Import password manager for getting VM credentials
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptRoot "PasswordManager.ps1") -Force

function Write-TestHeader {
    param([string]$Title)
    Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Success,
        [string]$Details = "",
        [string]$Recommendation = ""
    )
    
    $status = if ($Success) { "✓ PASS" } else { "✗ FAIL" }
    $color = if ($Success) { "Green" } else { "Red" }
    
    Write-Host "[$status] $TestName" -ForegroundColor $color
    if ($Details) {
        Write-Host "    Details: $Details" -ForegroundColor Gray
    }
    if ($Recommendation -and -not $Success) {
        Write-Host "    Action: $Recommendation" -ForegroundColor Yellow
    }
}

function Test-NetworkConnectivity {
    param([string]$IPAddress)
    
    Write-Host "`n🔌 Testing Network Connectivity..." -ForegroundColor Cyan
    
    $connectivityResults = @{}
    
    # Test ICMP ping
    try {
        $pingResult = Test-Connection -ComputerName $IPAddress -Count 2 -Quiet
        Write-TestResult "ICMP Ping" $pingResult "Response from $IPAddress"
        $connectivityResults.Ping = $pingResult
    } catch {
        Write-TestResult "ICMP Ping" $false "No response from $IPAddress" "Check VM power state and network configuration"
        $connectivityResults.Ping = $false
    }
    
    # Test common ports
    $ports = @{
        "RDP" = 3389
        "WinRM HTTP" = 5985
        "WinRM HTTPS" = 5986
        "SSH" = 22
    }
    
    foreach ($service in $ports.Keys) {
        $port = $ports[$service]
        try {
            $tcpTest = Test-NetConnection -ComputerName $IPAddress -Port $port -WarningAction SilentlyContinue
            Write-TestResult "$service (Port $port)" $tcpTest.TcpTestSucceeded "Connection to ${IPAddress}:$port"
            $connectivityResults[$service] = $tcpTest.TcpTestSucceeded
        } catch {
            Write-TestResult "$service (Port $port)" $false "Cannot connect to ${IPAddress}:$port" "Check Windows Firewall and service status"
            $connectivityResults[$service] = $false
        }
    }
    
    # Return true if essential services are available (ping and WinRM HTTP)
    return ($connectivityResults.Ping -and $connectivityResults."WinRM HTTP")
}

function Test-PowerShellRemoting {
    param([string]$IPAddress, [System.Management.Automation.PSCredential]$Credential)
    
    Write-Host "`n🔧 Testing PowerShell Remoting..." -ForegroundColor Cyan
    
    try {
        # Test basic PS remoting
        $session = New-PSSession -ComputerName $IPAddress -Credential $Credential -ErrorAction Stop
        Write-TestResult "PowerShell Session Creation" $true "Successfully created remote session"
        
        # Test basic command execution
        try {
            $osInfo = Invoke-Command -Session $session -ScriptBlock { 
                [PSCustomObject]@{
                    ComputerName = $env:COMPUTERNAME
                    OSVersion = (Get-ComputerInfo).WindowsProductName
                    PSVersion = $PSVersionTable.PSVersion.ToString()
                    Uptime = (Get-Date) - (gcim Win32_OperatingSystem).LastBootUpTime
                }
            } -ErrorAction Stop
            
            Write-TestResult "Remote Command Execution" $true "Retrieved system information"
            Write-Host "    Computer: $($osInfo.ComputerName)" -ForegroundColor Gray
            Write-Host "    OS: $($osInfo.OSVersion)" -ForegroundColor Gray
            Write-Host "    PowerShell: $($osInfo.PSVersion)" -ForegroundColor Gray
            Write-Host "    Uptime: $($osInfo.Uptime.ToString('dd\.hh\:mm\:ss'))" -ForegroundColor Gray
            
        } catch {
            Write-TestResult "Remote Command Execution" $false $_.Exception.Message "Check PowerShell execution policy and permissions"
            return $false
        }
        
        # Test administrative privileges
        try {
            $isAdmin = Invoke-Command -Session $session -ScriptBlock {
                ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
            }
            Write-TestResult "Administrative Privileges" $isAdmin "Running with admin rights: $isAdmin"
        } catch {
            Write-TestResult "Administrative Privileges" $false $_.Exception.Message
        }
        
        # Clean up session
        Remove-PSSession -Session $session
        return $true
        
    } catch {
        Write-TestResult "PowerShell Session Creation" $false $_.Exception.Message "Enable PowerShell remoting: Enable-PSRemoting -Force"
        return $false
    }
}

function Test-WindowsFeatures {
    param([string]$IPAddress, [System.Management.Automation.PSCredential]$Credential)
    
    Write-Host "`n🏗️ Testing Windows Features & Prerequisites..." -ForegroundColor Cyan
    
    try {
        $session = New-PSSession -ComputerName $IPAddress -Credential $Credential -ErrorAction Stop
        
        $featureTests = Invoke-Command -Session $session -ScriptBlock {
            $results = @{}
            
            # Test .NET Framework
            try {
                $dotNetVersion = (Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -Name Release -ErrorAction Stop).Release
                $results.DotNet = @{
                    Installed = $true
                    Version = switch ($dotNetVersion) {
                        { $_ -ge 533320 } { "4.8.1 or later" }
                        { $_ -ge 528040 } { "4.8" }
                        { $_ -ge 461808 } { "4.7.2" }
                        default { "4.6 or earlier" }
                    }
                }
            } catch {
                $results.DotNet = @{ Installed = $false; Error = $_.Exception.Message }
            }
            
            # Test PowerShell version
            $results.PowerShell = @{
                Version = $PSVersionTable.PSVersion
                IsCore = $PSVersionTable.PSEdition -eq "Core"
                ExecutionPolicy = Get-ExecutionPolicy
            }
            
            # Test Windows Management Framework / WMI
            try {
                $wmiTest = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
                $results.WMI = @{ Available = $true; OS = $wmiTest.Caption }
            } catch {
                $results.WMI = @{ Available = $false; Error = $_.Exception.Message }
            }
            
            # Test Internet connectivity from VM
            try {
                $internetTest = Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -WarningAction SilentlyContinue
                $results.Internet = @{ Available = $internetTest.TcpTestSucceeded }
            } catch {
                $results.Internet = @{ Available = $false; Error = $_.Exception.Message }
            }
            
            # Test Windows Updates status
            try {
                $updateService = Get-Service -Name "wuauserv" -ErrorAction Stop
                $results.WindowsUpdate = @{ 
                    ServiceRunning = $updateService.Status -eq "Running"
                    ServiceStatus = $updateService.Status.ToString()
                }
            } catch {
                $results.WindowsUpdate = @{ ServiceRunning = $false; Error = $_.Exception.Message }
            }
            
            return $results
        }
        
        # Process results
        Write-TestResult ".NET Framework" $featureTests.DotNet.Installed $featureTests.DotNet.Version "Install .NET Framework 4.8 or later"
        
        $psVersionOK = $featureTests.PowerShell.Version -ge [Version]"5.1"
        Write-TestResult "PowerShell Version" $psVersionOK "Version: $($featureTests.PowerShell.Version), Edition: $(if($featureTests.PowerShell.IsCore){'Core'}else{'Desktop'})" "Upgrade to PowerShell 5.1 or later"
        
        $execPolicyOK = $featureTests.PowerShell.ExecutionPolicy -ne "Restricted"
        Write-TestResult "PowerShell Execution Policy" $execPolicyOK "Policy: $($featureTests.PowerShell.ExecutionPolicy)" "Set-ExecutionPolicy RemoteSigned"
        
        Write-TestResult "WMI/CIM Access" $featureTests.WMI.Available $featureTests.WMI.OS "Check WMI service status"
        
        Write-TestResult "Internet Connectivity" $featureTests.Internet.Available "Can reach external DNS" "Check firewall and proxy settings"
        
        Write-TestResult "Windows Update Service" $featureTests.WindowsUpdate.ServiceRunning "Status: $($featureTests.WindowsUpdate.ServiceStatus)" "Start Windows Update service"
        
        Remove-PSSession -Session $session
        return $true
        
    } catch {
        Write-Host "✗ Could not test Windows features: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-Phase2Prerequisites {
    param([string]$IPAddress, [System.Management.Automation.PSCredential]$Credential)
    
    Write-Host "`n🎯 Testing Phase 2 API Prerequisites..." -ForegroundColor Cyan
    
    try {
        $session = New-PSSession -ComputerName $IPAddress -Credential $Credential -ErrorAction Stop
        
        $apiTests = Invoke-Command -Session $session -ScriptBlock {
            $results = @{}
            
            # Test if we can install modules
            try {
                $testModule = Get-Module -ListAvailable -Name "PowerShellGet" -ErrorAction Stop
                $results.ModuleInstallation = @{
                    PowerShellGet = $true
                    Version = $testModule.Version.ToString()
                }
            } catch {
                $results.ModuleInstallation = @{ PowerShellGet = $false; Error = $_.Exception.Message }
            }
            
            # Test TLS/SSL capabilities for API calls
            try {
                # Check supported TLS versions
                $tlsVersions = [System.Net.ServicePointManager]::SecurityProtocol
                $results.TLS = @{
                    Available = $true
                    Protocols = $tlsVersions.ToString()
                    SupportsTLS12 = $tlsVersions -band [System.Net.SecurityProtocolType]::Tls12
                }
            } catch {
                $results.TLS = @{ Available = $false; Error = $_.Exception.Message }
            }
            
            # Test REST API capabilities
            try {
                # Test if Invoke-RestMethod works
                $headers = @{ "Content-Type" = "application/json" }
                $testUrl = "https://httpbin.org/get"  # Simple test endpoint
                $restTest = Invoke-RestMethod -Uri $testUrl -Headers $headers -Method Get -TimeoutSec 10
                $results.REST = @{ Available = $true; TestURL = $testUrl }
            } catch {
                $results.REST = @{ Available = $false; Error = $_.Exception.Message }
            }
            
            # Check available disk space for tools/downloads
            try {
                $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
                $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
                $results.DiskSpace = @{
                    Available = $freeSpaceGB -gt 2
                    FreeSpaceGB = $freeSpaceGB
                }
            } catch {
                $results.DiskSpace = @{ Available = $false; Error = $_.Exception.Message }
            }
            
            # Test if we can create directories and files
            try {
                $testPath = "C:\temp\api-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                New-Item -Path $testPath -ItemType Directory -Force | Out-Null
                "test" | Out-File -FilePath "$testPath\test.txt"
                $canWrite = Test-Path "$testPath\test.txt"
                Remove-Item -Path $testPath -Recurse -Force
                $results.FileSystem = @{ CanWrite = $canWrite }
            } catch {
                $results.FileSystem = @{ CanWrite = $false; Error = $_.Exception.Message }
            }
            
            return $results
        }
        
        # Process Phase 2 results
        Write-TestResult "PowerShell Module Support" $apiTests.ModuleInstallation.PowerShellGet "PowerShellGet: $($apiTests.ModuleInstallation.Version)" "Install PowerShellGet module"
        
        Write-TestResult "TLS/SSL Support" $apiTests.TLS.Available "Protocols: $($apiTests.TLS.Protocols)" "Enable TLS 1.2 support"
        
        if ($apiTests.TLS.Available) {
            Write-TestResult "TLS 1.2 Support" $apiTests.TLS.SupportsTLS12 "Required for secure API calls" "Enable TLS 1.2: [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12"
        }
        
        Write-TestResult "REST API Capabilities" $apiTests.REST.Available "Can make HTTP requests" "Check proxy settings and internet access"
        
        $diskSpaceOK = $apiTests.DiskSpace.Available
        Write-TestResult "Sufficient Disk Space" $diskSpaceOK "Free space: $($apiTests.DiskSpace.FreeSpaceGB) GB" "Free up disk space (minimum 2GB recommended)"
        
        Write-TestResult "File System Access" $apiTests.FileSystem.CanWrite "Can create files and directories" "Check user permissions and disk space"
        
        Remove-PSSession -Session $session
        return $true
        
    } catch {
        Write-Host "✗ Could not test Phase 2 prerequisites: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Get-VMCredentials {
    Write-Host "`n🔐 Getting VM Credentials..." -ForegroundColor Cyan
    
    # Try to get cached VM administrator password
    $vmPassword = Get-CachedPassword -Username "vm-administrator"
    
    if ($vmPassword) {
        Write-Host "✓ Using cached password for: vm-administrator" -ForegroundColor Green
        $securePassword = ConvertTo-SecureString $vmPassword -AsPlainText -Force
        return New-Object System.Management.Automation.PSCredential("Administrator", $securePassword)
    } else {
        Write-Host "[INFO] No cached VM password found. Please enter credentials." -ForegroundColor Yellow
        return Get-Credential -UserName "Administrator" -Message "Enter credentials for VM Administrator"
    }
}

function Show-ReadinessSummary {
    param([hashtable]$Results)
    
    Write-TestHeader "VM READINESS SUMMARY"
    
    $totalTests = $Results.Values | Measure-Object | Select-Object -ExpandProperty Count
    $passedTests = $Results.Values | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
    
    if ($totalTests -eq 0) {
        $readinessPercentage = 0
    } else {
        $readinessPercentage = [math]::Round(($passedTests / $totalTests) * 100, 1)
    }
    
    Write-Host "Overall Readiness: $readinessPercentage% ($passedTests/$totalTests tests passed)" -ForegroundColor $(if($readinessPercentage -ge 80){'Green'}elseif($readinessPercentage -ge 60){'Yellow'}else{'Red'})
    
    # Categorize readiness
    if ($readinessPercentage -ge 90) {
        Write-Host "`n🎉 VM IS READY FOR PHASE 2!" -ForegroundColor Green
        Write-Host "   The VM can accept PowerShell commands and is prepared for Nutanix v4 API setup." -ForegroundColor Green
    } elseif ($readinessPercentage -ge 70) {
        Write-Host "`n⚠️ VM IS MOSTLY READY" -ForegroundColor Yellow
        Write-Host "   Minor issues detected. Phase 2 can proceed with some manual configuration." -ForegroundColor Yellow
    } else {
        Write-Host "`n❌ VM NEEDS PREPARATION" -ForegroundColor Red
        Write-Host "   Significant issues detected. Resolve failing tests before Phase 2." -ForegroundColor Red
    }
    
    Write-Host "`n📋 Next Steps for Phase 2:" -ForegroundColor Cyan
    Write-Host "   1. Install Nutanix PowerShell modules" -ForegroundColor White
    Write-Host "   2. Configure Nutanix v4 API credentials" -ForegroundColor White
    Write-Host "   3. Set up development environment (VS Code, Git)" -ForegroundColor White
    Write-Host "   4. Test API connectivity to Prism Central" -ForegroundColor White
}

# Main execution
Write-TestHeader "WINDOWS VM READINESS TEST FOR PHASE 2"
Write-Host "Target VM: $VMIPAddress" -ForegroundColor White
Write-Host "Test Level: $TestLevel" -ForegroundColor White

# Get credentials if not provided
if (-not $VMCredential) {
    $VMCredential = Get-VMCredentials
    if (-not $VMCredential) {
        Write-Host "❌ Cannot proceed without VM credentials." -ForegroundColor Red
        exit 1
    }
}

# Initialize results tracking
$testResults = @{}

# Run tests based on level
$testResults.NetworkConnectivity = Test-NetworkConnectivity -IPAddress $VMIPAddress

if ($testResults.NetworkConnectivity) {
    $testResults.PowerShellRemoting = Test-PowerShellRemoting -IPAddress $VMIPAddress -Credential $VMCredential
    
    if ($testResults.PowerShellRemoting) {
        if ($TestLevel -in @("Standard", "Full")) {
            $testResults.WindowsFeatures = Test-WindowsFeatures -IPAddress $VMIPAddress -Credential $VMCredential
        }
        
        if ($TestLevel -eq "Full") {
            $testResults.Phase2Prerequisites = Test-Phase2Prerequisites -IPAddress $VMIPAddress -Credential $VMCredential
        }
    }
} else {
    Write-Host "`n❌ Network connectivity failed. Cannot proceed with remote tests." -ForegroundColor Red
}

# Show summary
Show-ReadinessSummary -Results $testResults

Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
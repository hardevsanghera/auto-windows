#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test WinRM connectivity with SSL certificate validation bypass

.DESCRIPTION
    Provides wrapper functions to test WinRM HTTPS connectivity while
    bypassing SSL certificate validation for self-signed certificates.

.EXAMPLE
    Test-WSManWithSSLBypass -ComputerName HARDEV-1021 -Port 5986
#>

function Test-WSManWithSSLBypass {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,
        
        [Parameter(Mandatory = $false)]
        [int]$Port = 5986,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )
    
    Write-Host "Testing WinRM HTTPS connection to $ComputerName`:$Port..." -ForegroundColor Cyan
    
    # Save current certificate validation callback
    $originalCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
    
    try {
        # Temporarily disable certificate validation
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
        
        # Test WSMan connection
        if ($Credential) {
            $result = Test-WSMan -ComputerName $ComputerName -UseSSL -Port $Port -Credential $Credential -ErrorAction Stop
        } else {
            $result = Test-WSMan -ComputerName $ComputerName -UseSSL -Port $Port -ErrorAction Stop
        }
        
        Write-Host "✓ WinRM HTTPS connection successful!" -ForegroundColor Green
        Write-Host "  Product Version: $($result.ProductVersion)" -ForegroundColor Gray
        Write-Host "  Protocol Version: $($result.ProtocolVersion)" -ForegroundColor Gray
        
        return $true
        
    } catch {
        Write-Host "✗ WinRM HTTPS connection failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    } finally {
        # Always restore original certificate validation
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $originalCallback
    }
}

function Test-PSRemotingWithSSLBypass {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,
        
        [Parameter(Mandatory = $false)]
        [int]$Port = 5986,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )
    
    Write-Host "Testing PowerShell remoting HTTPS to $ComputerName`:$Port..." -ForegroundColor Cyan
    
    try {
        # Create session options to skip certificate checks
        $sessionOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck
        
        # Test PS remoting connection
        if ($Credential) {
            $testSession = New-PSSession -ComputerName $ComputerName -Port $Port -UseSSL -SessionOption $sessionOptions -Credential $Credential -ErrorAction Stop
        } else {
            $testSession = New-PSSession -ComputerName $ComputerName -Port $Port -UseSSL -SessionOption $sessionOptions -ErrorAction Stop
        }
        
        # Test a simple command
        $remoteInfo = Invoke-Command -Session $testSession -ScriptBlock {
            [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                OSVersion = (Get-ComputerInfo).WindowsProductName
                TLSVersion = [System.Net.ServicePointManager]::SecurityProtocol.ToString()
            }
        }
        
        Write-Host "✓ PowerShell remoting HTTPS successful!" -ForegroundColor Green
        Write-Host "  Remote Computer: $($remoteInfo.ComputerName)" -ForegroundColor Gray
        Write-Host "  PowerShell Version: $($remoteInfo.PowerShellVersion)" -ForegroundColor Gray
        Write-Host "  TLS Protocol: $($remoteInfo.TLSVersion)" -ForegroundColor Gray
        
        # Clean up
        Remove-PSSession -Session $testSession
        return $true
        
    } catch {
        Write-Host "✗ PowerShell remoting HTTPS failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Export functions for use in other scripts
Export-ModuleMember -Function Test-WSManWithSSLBypass, Test-PSRemotingWithSSLBypass

# Quick test examples
Write-Host "`n🔍 SSL Bypass Testing Functions Loaded!" -ForegroundColor Cyan
Write-Host "`nUsage Examples:" -ForegroundColor Yellow
Write-Host "  Test-WSManWithSSLBypass -ComputerName HARDEV-1021 -Port 5986" -ForegroundColor White
Write-Host "  Test-PSRemotingWithSSLBypass -ComputerName HARDEV-1021 -Port 5986" -ForegroundColor White
Write-Host "  Test-WSManWithSSLBypass -ComputerName 10.38.19.26 -Port 5986 -Credential (Get-Credential)" -ForegroundColor White
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick VM IP checker - opens Prism Central web interface for manual verification

.DESCRIPTION
    Simple script to check VM IP when API access is limited.
    Opens Prism Central web interface and provides manual instructions.
#>

# Get VM info from deployment results
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$resultsFile = Join-Path $scriptRoot "temp\phase1-results.json"

if (-not (Test-Path $resultsFile)) {
    Write-Host "[ERROR] No deployment results found. Please run deployment first." -ForegroundColor Red
    exit 1
}

try {
    $results = Get-Content $resultsFile | ConvertFrom-Json
    $vmName = $results.VMName
    $vmUUID = $results.VMUUID
    $taskUUID = $results.TaskUUID
    
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "   QUICK VM IP CHECK - MANUAL METHOD" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    
    Write-Host "`n📋 VM Information:" -ForegroundColor Green
    Write-Host "   Name: $vmName" -ForegroundColor White
    Write-Host "   UUID: $vmUUID" -ForegroundColor Gray
    Write-Host "   Task: $taskUUID" -ForegroundColor Gray
    
    Write-Host "`n🌐 Opening Prism Central Web Interface..." -ForegroundColor Cyan
    Start-Process "https://10.38.19.9:9440"
    
    Write-Host "`n📝 Manual Steps to Get IP Address:" -ForegroundColor Yellow
    Write-Host "   1. Log into Prism Central: https://10.38.19.9:9440" -ForegroundColor White
    Write-Host "   2. Navigate to: VMs (left menu)" -ForegroundColor White
    Write-Host "   3. Find VM: $vmName" -ForegroundColor Green
    Write-Host "   4. Click on the VM name to view details" -ForegroundColor White
    Write-Host "   5. Check the 'Network' section for IP address" -ForegroundColor White
    
    Write-Host "`n⏱️  Expected Timeline:" -ForegroundColor Cyan
    Write-Host "   • VM Boot Time: 5-10 minutes for Windows" -ForegroundColor Gray
    Write-Host "   • IP Assignment: May take additional 2-5 minutes" -ForegroundColor Gray
    Write-Host "   • If no IP after 15 minutes, check VM console" -ForegroundColor Gray
    
    Write-Host "`n🔗 Once you have the IP address:" -ForegroundColor Green
    Write-Host "   • RDP: mstsc /v:<IP_ADDRESS>" -ForegroundColor White
    Write-Host "   • SSH: ssh Administrator@<IP_ADDRESS>" -ForegroundColor White
    Write-Host "   • Username: Administrator" -ForegroundColor White
    Write-Host "   • Password: <VM Admin Password you set>" -ForegroundColor White
    
    Write-Host "`n🔧 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   • No IP? Check VM is powered ON" -ForegroundColor Gray
    Write-Host "   • Boot issues? Open VM console in Prism Central" -ForegroundColor Gray
    Write-Host "   • Network issues? Verify subnet configuration" -ForegroundColor Gray
    
    Write-Host ("=" * 60) -ForegroundColor Cyan
    
    # Keep window open
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
} catch {
    Write-Host "[ERROR] Could not read deployment results: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
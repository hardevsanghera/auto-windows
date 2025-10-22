# Test with input redirection
$deploymentDir = "C:\Users\hardev.sanghera\Documents\v3\auto-windows\temp\repos\deploy_win_vm_v1"
$automationFile = "C:\Users\hardev.sanghera\Documents\v3\auto-windows\temp\vm_automation_input.json"
$venvPython = Join-Path $deploymentDir "venv\Scripts\python.exe"

# Read automation data
$automationData = Get-Content $automationFile | ConvertFrom-Json

# Create input script
$inputScript = @"
$($automationData.vm_name)
$($automationData.admin_password)
$($automationData.confirm_password)
$($automationData.proceed_deployment)
$($automationData.pc_password)
"@

$inputScript | Out-File -FilePath "$deploymentDir\input.txt" -Encoding UTF8

# Set environment variables
$env:PYTHONIOENCODING = "utf-8"

# Change to deployment directory
Push-Location $deploymentDir

try {
    Write-Host "Running deployment with input redirection..." -ForegroundColor Cyan
    
    # Run with input redirection
    $output = cmd /c "type input.txt | `"$venvPython`" deploy_win_vm.py --deploy" 2>&1
    
    Write-Host "Deployment output:" -ForegroundColor Green
    Write-Host ($output -join "`n") -ForegroundColor Cyan
}
finally {
    Pop-Location
    Remove-Item "$deploymentDir\input.txt" -ErrorAction SilentlyContinue
}
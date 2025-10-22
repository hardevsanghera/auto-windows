# Quick test script for VM deployment
$deploymentDir = "C:\Users\hardev.sanghera\Documents\v3\auto-windows\temp\repos\deploy_win_vm_v1"
$automationFile = "C:\Users\hardev.sanghera\Documents\v3\auto-windows\temp\vm_automation_input.json"
$venvPython = Join-Path $deploymentDir "venv\Scripts\python.exe"

# Set environment variables
$env:PYTHONIOENCODING = "utf-8"
$env:VM_AUTOMATION_FILE = $automationFile

# Change to deployment directory
Push-Location $deploymentDir

try {
    Write-Host "Testing VM deployment with automation..." -ForegroundColor Cyan
    Write-Host "Python path: $venvPython" -ForegroundColor Yellow
    Write-Host "Automation file: $automationFile" -ForegroundColor Yellow
    Write-Host "Working directory: $deploymentDir" -ForegroundColor Yellow
    
    # Run with timeout
    $job = Start-Job -ScriptBlock {
        param($pythonPath, $workingDir, $automationFile)
        Set-Location $workingDir
        $env:PYTHONIOENCODING = "utf-8"
        $env:VM_AUTOMATION_FILE = $automationFile
        & "$pythonPath" "deploy_win_vm.py" "--deploy" 2>&1
    } -ArgumentList $venvPython, $deploymentDir, $automationFile
    
    # Wait for job with timeout
    $result = Wait-Job $job -Timeout 60
    
    if ($result) {
        $output = Receive-Job $job
        Write-Host "Deployment output:" -ForegroundColor Green
        Write-Host ($output -join "`n") -ForegroundColor Cyan
    } else {
        Write-Host "Deployment timed out after 60 seconds" -ForegroundColor Red
        Stop-Job $job
    }
    
    Remove-Job $job -Force
}
finally {
    Pop-Location
}
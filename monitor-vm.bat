@echo off
echo ===============================================
echo VM IP Address Monitor - Phase 1 Completion
echo ===============================================
echo VM UUID: eb6e48a3-efae-4a62-97e1-657af8cae401
echo VM Name: hardev-VM
echo.
echo Checking VM status...
echo.

cd /d "c:\Users\hardev.sanghera\Documents\v3\auto-windows"
& 'C:\Users\hardev.sanghera\AppData\Local\Programs\Python\Python313\python.exe' check_vm_status.py eb6e48a3-efae-4a62-97e1-657af8cae401

echo.
echo ===============================================
echo If IP address found, vm-details.json will be created
echo in the temp\ directory for Phase 2 usage.
echo.
echo Run this script again in a few minutes if no IP yet.
echo ===============================================
pause
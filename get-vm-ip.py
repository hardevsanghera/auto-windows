#!/usr/bin/env python3
"""
Get VM IP Address from Nutanix Prism Central
Query VM network information using REST API
"""

import requests
import json
import getpass
import sys
import os

# Try to import urllib3 and disable SSL warnings
try:
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
except ImportError:
    print("[WARN] urllib3 not available - SSL warnings may appear")

def get_vm_ip_address(pc_host, username, password, vm_uuid):
    """
    Get VM IP address from Prism Central using REST API
    """
    
    # Prism Central API endpoint
    base_url = f"https://{pc_host}:9440/api/nutanix/v3"
    vm_url = f"{base_url}/vms/{vm_uuid}"
    
    # Authentication headers
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    try:
        print(f"[INFO] Querying VM details for UUID: {vm_uuid}")
        print(f"[INFO] Connecting to Prism Central: {pc_host}")
        
        # Make API call to get VM details
        response = requests.get(
            vm_url,
            auth=(username, password),
            headers=headers,
            verify=False,
            timeout=30
        )
        
        if response.status_code == 200:
            vm_data = response.json()
            
            # Extract VM information
            vm_name = vm_data.get('spec', {}).get('name', 'Unknown')
            power_state = vm_data.get('spec', {}).get('resources', {}).get('power_state', 'Unknown')
            
            print(f"[OK] VM Name: {vm_name}")
            print(f"[OK] Power State: {power_state}")
            
            # Look for network information
            nic_list = vm_data.get('spec', {}).get('resources', {}).get('nic_list', [])
            
            if not nic_list:
                print("[WARN] No network interfaces found for this VM")
                return None
            
            # Check each NIC for IP address information
            ip_addresses = []
            for i, nic in enumerate(nic_list):
                print(f"\n[INFO] Network Interface {i+1}:")
                
                # Check if there's IP address information
                if 'ip_endpoint_list' in nic:
                    for endpoint in nic['ip_endpoint_list']:
                        ip = endpoint.get('ip', 'Not assigned')
                        ip_type = endpoint.get('type', 'Unknown')
                        print(f"  IP Address: {ip} (Type: {ip_type})")
                        if ip != 'Not assigned':
                            ip_addresses.append(ip)
                else:
                    print("  IP Address: Not yet assigned")
                
                # Show subnet information
                subnet_ref = nic.get('subnet_reference', {})
                if subnet_ref:
                    print(f"  Subnet UUID: {subnet_ref.get('uuid', 'Unknown')}")
            
            if ip_addresses:
                print(f"\n[SUCCESS] Found IP address(es): {', '.join(ip_addresses)}")
                return ip_addresses[0]  # Return the first IP address
            else:
                print(f"\n[WARN] VM is powered {power_state.lower()} but no IP address assigned yet")
                print("[INFO] This is normal if the VM is still booting or DHCP hasn't assigned an IP")
                return None
                
        else:
            print(f"[ERROR] Failed to get VM details. HTTP {response.status_code}")
            print(f"[ERROR] Response: {response.text}")
            return None
            
    except requests.exceptions.RequestException as e:
        print(f"[ERROR] Network error: {e}")
        return None
    except Exception as e:
        print(f"[ERROR] Unexpected error: {e}")
        return None

def get_cached_password(username):
    """Try to get password from PowerShell password manager"""
    try:
        # Try to call PowerShell to get cached password
        import subprocess
        
        ps_command = f'''
        Import-Module "{os.path.join(os.path.dirname(__file__), 'PasswordManager.ps1')}"
        $password = Get-CachedPassword -Username "{username}"
        if ($password) {{
            Write-Output $password
        }} else {{
            Write-Output ""
        }}
        '''
        
        result = subprocess.run(
            ["powershell", "-Command", ps_command],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
        else:
            return None
            
    except Exception:
        return None

def get_latest_vm_uuid():
    """Get VM UUID from the latest deployment results"""
    try:
        results_file = os.path.join("temp", "phase1-results.json")
        if os.path.exists(results_file):
            with open(results_file, 'r') as f:
                results = json.load(f)
                return results.get('VMUUID'), results.get('VMName', 'Unknown')
        return None, None
    except Exception as e:
        print(f"[WARN] Could not read deployment results: {e}")
        return None, None

def main():
    """Main function"""
    
    # Configuration
    pc_host = "10.38.19.9"
    username = "admin"
    
    print("=" * 60)
    print("GET VM IP ADDRESS FROM NUTANIX PRISM CENTRAL")
    print("=" * 60)
    
    # Get VM UUID from deployment results
    vm_uuid, vm_name = get_latest_vm_uuid()
    
    if not vm_uuid:
        print("[ERROR] No deployment results found. Please run deployment first.")
        return
    
    print(f"[INFO] Checking IP for VM: {vm_name} (UUID: {vm_uuid})")
    
    # Try to get cached password first
    password = get_cached_password(username)
    
    if password:
        print(f"✓ Using cached password for: {username}")
    else:
        # Get password manually
        password = getpass.getpass(f"Enter password for {username}: ")
    
    # Query VM IP address
    ip_address = get_vm_ip_address(pc_host, username, password, vm_uuid)
    
    if ip_address:
        print(f"\n🎯 VM IP Address: {ip_address}")
        print(f"\n💡 You can now connect to your VM using:")
        print(f"   RDP: mstsc /v:{ip_address}")
        print(f"   SSH: ssh Administrator@{ip_address}")
    else:
        print(f"\n⏳ VM IP not available yet. Try again in a few minutes.")
        print(f"   The VM may still be booting or obtaining DHCP lease.")

if __name__ == "__main__":
    main()
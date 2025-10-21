#!/usr/bin/env python3
"""
Quick VM Status Check Script
Gets current VM status and IP if available
"""

import requests
import urllib3
import getpass
import json
import sys

# Disable SSL certificate warnings globally for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def check_vm_status(pc_ip, username, password, vm_uuid):
    """
    Quick check of VM status and IP address
    """
    base_url = f"https://{pc_ip}:9440/api/nutanix/v3"
    headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    
    try:
        # Query VM details
        vm_url = f"{base_url}/vms/{vm_uuid}"
        response = requests.get(
            vm_url,
            auth=(username, password),
            headers=headers,
            verify=False,
            timeout=30
        )
        
        if response.status_code == 200:
            vm_data = response.json()
            
            # Get basic VM info
            power_state = vm_data.get('spec', {}).get('resources', {}).get('power_state', 'UNKNOWN')
            vm_name = vm_data.get('spec', {}).get('name', 'Unknown')
            
            print(f"🖥️  VM Name: {vm_name}")
            print(f"⚡ Power State: {power_state}")
            print(f"🆔 UUID: {vm_uuid}")
            
            # Look for IP addresses
            nic_list = vm_data.get('status', {}).get('resources', {}).get('nic_list', [])
            ip_found = False
            
            print(f"🌐 Network Interfaces:")
            for i, nic in enumerate(nic_list):
                print(f"   NIC {i + 1}:")
                ip_endpoint_list = nic.get('ip_endpoint_list', [])
                
                if not ip_endpoint_list:
                    print(f"     No IP endpoints assigned")
                else:
                    for ip_endpoint in ip_endpoint_list:
                        ip_address = ip_endpoint.get('ip')
                        ip_type = ip_endpoint.get('type', 'UNKNOWN')
                        
                        if ip_address:
                            print(f"     IP: {ip_address} (Type: {ip_type})")
                            if ip_type in ['ASSIGNED', 'LEARNED']:
                                ip_found = True
                                
                                # Save this IP for Phase 2
                                result = {
                                    'vm_uuid': vm_uuid,
                                    'vm_name': vm_name,
                                    'ip_address': ip_address,
                                    'power_state': power_state,
                                    'status': 'SUCCESS',
                                    'timestamp': json.dumps(None, default=str)
                                }
                                
                                result_file = "temp/vm-details.json"
                                with open(result_file, 'w') as f:
                                    json.dump(result, f, indent=2)
                                
                                print(f"\n✅ VM IP address found and saved!")
                                print(f"📄 Details saved to: {result_file}")
                                return True
            
            if not ip_found:
                print(f"\n⏳ VM is powered on but no assigned IP address yet")
                print(f"   This is normal - Windows VM may take several minutes to fully boot")
                print(f"   Run this script again in a few minutes to check")
                
                # Save current status
                result = {
                    'vm_uuid': vm_uuid,
                    'vm_name': vm_name,
                    'ip_address': None,
                    'power_state': power_state,
                    'status': 'PENDING',
                    'message': 'VM powered on, waiting for IP assignment'
                }
                
                result_file = "temp/vm-details.json"
                with open(result_file, 'w') as f:
                    json.dump(result, f, indent=2)
                
                return False
                
        else:
            print(f"❌ API call failed with status {response.status_code}")
            print(f"   Response: {response.text}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Request failed: {e}")
        return False

def main():
    if len(sys.argv) != 2:
        print("Usage: python check_vm_status.py <VM_UUID>")
        sys.exit(1)
    
    vm_uuid = sys.argv[1]
    
    # Load deployment configuration for PC details
    try:
        with open("temp/repos/deploy_win_vm_v1/deployment_config.json", 'r') as f:
            config = json.load(f)
        pc_ip = config['pc_ip']
        username = config['username']
    except FileNotFoundError:
        print("Error: deployment_config.json not found")
        sys.exit(1)
    except KeyError as e:
        print(f"Error: Missing configuration key: {e}")
        sys.exit(1)
    
    # Get password
    password = getpass.getpass(f"Enter password for {username}: ")
    
    # Check VM status
    success = check_vm_status(pc_ip, username, password, vm_uuid)
    
    if success:
        print(f"\n🎉 Phase 1 Complete! VM is ready with IP address.")
    else:
        print(f"\n⏳ Phase 1 In Progress - VM is booting, check again soon.")

if __name__ == "__main__":
    main()
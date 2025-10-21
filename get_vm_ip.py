#!/usr/bin/env python3
"""
VM IP Address Retrieval Script
Queries Nutanix Prism Central for VM details and retrieves IP address
"""

import requests
import urllib3
import getpass
import json
import time
import sys

# Disable SSL certificate warnings globally for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def get_vm_ip_address(pc_ip, username, password, vm_uuid, max_wait_minutes=10):
    """
    Query VM details from Prism Central and return the IP address
    """
    base_url = f"https://{pc_ip}:9440/api/nutanix/v3"
    headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    
    max_attempts = max_wait_minutes * 2  # Check every 30 seconds
    
    print(f"🔍 Waiting for VM {vm_uuid} to get IP address...")
    print(f"   Maximum wait time: {max_wait_minutes} minutes")
    
    for attempt in range(max_attempts):
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
                
                # Check VM power state
                power_state = vm_data.get('spec', {}).get('resources', {}).get('power_state', 'UNKNOWN')
                vm_name = vm_data.get('spec', {}).get('name', 'Unknown')
                
                print(f"   Attempt {attempt + 1}/{max_attempts}: VM '{vm_name}' power state: {power_state}")
                
                # Look for IP addresses in VM resources
                nic_list = vm_data.get('status', {}).get('resources', {}).get('nic_list', [])
                
                for nic in nic_list:
                    ip_endpoint_list = nic.get('ip_endpoint_list', [])
                    for ip_endpoint in ip_endpoint_list:
                        ip_address = ip_endpoint.get('ip')
                        ip_type = ip_endpoint.get('type', 'UNKNOWN')
                        
                        if ip_address and ip_type == 'ASSIGNED':
                            print(f"✅ Found IP address: {ip_address}")
                            return {
                                'vm_uuid': vm_uuid,
                                'vm_name': vm_name,
                                'ip_address': ip_address,
                                'power_state': power_state,
                                'status': 'SUCCESS'
                            }
                
                # If VM is powered on but no IP yet, continue waiting
                if power_state == 'ON':
                    print(f"   VM is powered on but no IP address assigned yet...")
                elif power_state == 'OFF':
                    print(f"   VM is powered off, waiting for startup...")
                
            else:
                print(f"   API call failed with status {response.status_code}")
                
        except requests.exceptions.RequestException as e:
            print(f"   Request failed: {e}")
        
        # Wait 30 seconds before next attempt
        if attempt < max_attempts - 1:
            time.sleep(30)
    
    print(f"❌ Timeout: Could not retrieve IP address within {max_wait_minutes} minutes")
    return {
        'vm_uuid': vm_uuid,
        'vm_name': vm_data.get('spec', {}).get('name', 'Unknown') if 'vm_data' in locals() else 'Unknown',
        'ip_address': None,
        'power_state': vm_data.get('spec', {}).get('resources', {}).get('power_state', 'UNKNOWN') if 'vm_data' in locals() else 'UNKNOWN',
        'status': 'TIMEOUT'
    }

def main():
    if len(sys.argv) != 2:
        print("Usage: python get_vm_ip.py <VM_UUID>")
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
    
    # Get VM IP address
    result = get_vm_ip_address(pc_ip, username, password, vm_uuid)
    
    # Save result to file for Phase 2
    result_file = "temp/vm-details.json"
    with open(result_file, 'w') as f:
        json.dump(result, f, indent=2)
    
    print(f"\n📄 VM details saved to: {result_file}")
    
    if result['status'] == 'SUCCESS':
        print(f"🎉 VM '{result['vm_name']}' is ready!")
        print(f"   IP Address: {result['ip_address']}")
        print(f"   UUID: {result['vm_uuid']}")
    else:
        print(f"⚠️  VM details saved but IP address not available")
        print(f"   Check Prism Central for VM status")

if __name__ == "__main__":
    main()
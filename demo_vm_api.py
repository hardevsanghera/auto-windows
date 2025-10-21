#!/usr/bin/env python3
"""
Nutanix v3 REST API Demo - VM IP Address Retrieval
Shows the exact API endpoint and response structure for getting VM IP addresses
"""

import requests
import urllib3
import getpass
import json
import sys

# Disable SSL certificate warnings globally for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def demo_vm_api_call(pc_ip, username, password, vm_uuid):
    """
    Demonstrate the exact REST API call to get VM details including IP address
    """
    
    # Nutanix v3 API Base URL
    base_url = f"https://{pc_ip}:9440/api/nutanix/v3"
    
    # API Endpoint for VM details
    vm_endpoint = f"{base_url}/vms/{vm_uuid}"
    
    # HTTP Headers
    headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    
    print("=" * 70)
    print("NUTANIX v3 REST API DEMONSTRATION")
    print("=" * 70)
    print()
    
    print("🔗 API ENDPOINT:")
    print(f"   Method: GET")
    print(f"   URL: {vm_endpoint}")
    print()
    
    print("📋 HEADERS:")
    for key, value in headers.items():
        print(f"   {key}: {value}")
    print()
    
    print("🔐 AUTHENTICATION:")
    print(f"   Type: HTTP Basic Authentication")
    print(f"   Username: {username}")
    print(f"   Password: [HIDDEN]")
    print()
    
    print("🚀 MAKING API CALL...")
    print("-" * 40)
    
    try:
        response = requests.get(
            vm_endpoint,
            auth=(username, password),
            headers=headers,
            verify=False,  # Skip SSL verification for self-signed certs
            timeout=30
        )
        
        print(f"📊 RESPONSE STATUS: {response.status_code}")
        print()
        
        if response.status_code == 200:
            vm_data = response.json()
            
            print("✅ SUCCESS - VM Data Retrieved")
            print("-" * 40)
            
            # Show key parts of the response
            vm_name = vm_data.get('spec', {}).get('name', 'Unknown')
            power_state = vm_data.get('spec', {}).get('resources', {}).get('power_state', 'UNKNOWN')
            
            print("🖥️  BASIC VM INFO:")
            print(f"   Name: {vm_name}")
            print(f"   UUID: {vm_uuid}")
            print(f"   Power State: {power_state}")
            print()
            
            print("🌐 NETWORK INTERFACE DATA STRUCTURE:")
            print("   Path in JSON: status.resources.nic_list[]")
            print()
            
            # Navigate to network interfaces
            nic_list = vm_data.get('status', {}).get('resources', {}).get('nic_list', [])
            
            if nic_list:
                for i, nic in enumerate(nic_list):
                    print(f"   NIC {i + 1}:")
                    print(f"   └── ip_endpoint_list: {json.dumps(nic.get('ip_endpoint_list', []), indent=6)}")
                    
                    ip_endpoint_list = nic.get('ip_endpoint_list', [])
                    if ip_endpoint_list:
                        for j, ip_endpoint in enumerate(ip_endpoint_list):
                            ip_address = ip_endpoint.get('ip')
                            ip_type = ip_endpoint.get('type', 'UNKNOWN')
                            
                            print(f"       IP Endpoint {j + 1}:")
                            print(f"       ├── IP Address: {ip_address}")
                            print(f"       └── Type: {ip_type}")
                            
                            if ip_type == 'ASSIGNED' and ip_address:
                                print(f"       ✅ FOUND ASSIGNED IP: {ip_address}")
                    else:
                        print(f"       ⏳ No IP endpoints assigned yet")
                    print()
            else:
                print("   ❌ No network interfaces found")
            
            print("📄 JSON RESPONSE STRUCTURE (Key Sections):")
            print("-" * 40)
            
            # Show relevant parts of the JSON structure
            relevant_data = {
                "metadata": {
                    "uuid": vm_data.get('metadata', {}).get('uuid'),
                    "kind": vm_data.get('metadata', {}).get('kind')
                },
                "spec": {
                    "name": vm_data.get('spec', {}).get('name'),
                    "resources": {
                        "power_state": vm_data.get('spec', {}).get('resources', {}).get('power_state')
                    }
                },
                "status": {
                    "resources": {
                        "nic_list": vm_data.get('status', {}).get('resources', {}).get('nic_list', [])
                    }
                }
            }
            
            print(json.dumps(relevant_data, indent=2))
            
        else:
            print(f"❌ ERROR - API call failed")
            print(f"   Status Code: {response.status_code}")
            print(f"   Response: {response.text}")
            
    except requests.exceptions.RequestException as e:
        print(f"❌ REQUEST FAILED: {e}")
    
    print()
    print("=" * 70)
    print("API CALL DEMONSTRATION COMPLETE")
    print("=" * 70)

def main():
    if len(sys.argv) != 2:
        print("Usage: python demo_vm_api.py <VM_UUID>")
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
    
    # Demonstrate the API call
    demo_vm_api_call(pc_ip, username, password, vm_uuid)

if __name__ == "__main__":
    main()
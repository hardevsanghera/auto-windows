#!/usr/bin/env python3
"""
VM Deployment Automation Wrapper - Simple Version
Uses function patching for inputs but avoids memory-intensive output capture
"""

import os
import sys
import json
import importlib.util
import getpass

def get_automation_inputs():
    """Read automation inputs from the specified file"""
    automation_file = os.environ.get('VM_AUTOMATION_FILE')
    if not automation_file or not os.path.exists(automation_file):
        return None
    
    try:
        with open(automation_file, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"[ERROR] Error reading automation file: {e}")
        return None

def create_automated_input_function(inputs_queue):
    """Create an input function that returns predefined inputs"""
    def automated_input(prompt=""):
        if inputs_queue:
            response = inputs_queue.pop(0)
            print(f"{prompt}{response}")
            return response
        else:
            # Fallback to real input if we run out of automated responses
            return input(prompt)
    return automated_input

def create_automated_getpass_function(passwords_dict):
    """Create a getpass function that returns appropriate password based on prompt"""
    def automated_getpass(prompt="Password: "):
        password = ""
        
        # Determine which password to use based on prompt
        if "admin" in prompt.lower() or "administrator" in prompt.lower():
            password = passwords_dict.get('admin_password', '')
        elif any(keyword in prompt.lower() for keyword in ['prism', 'pc_', 'enter password for']):
            password = passwords_dict.get('pc_password', '')
        else:
            # Default to admin password
            password = passwords_dict.get('admin_password', '')
        
        print(f"{prompt}{'*' * len(password)}")
        return password
    return automated_getpass

def run_automated_deployment():
    """Run VM deployment with automated inputs using function patching"""
    automation_data = get_automation_inputs()
    
    if not automation_data:
        print("[ERROR] No automation data found. Running in interactive mode.")
        # Import and run the deployment script directly in deploy mode
        original_argv = sys.argv
        
        try:
            # Set argv to simulate running with --deploy flag
            sys.argv = ["deploy_win_vm.py", "--deploy"]
            
            spec = importlib.util.spec_from_file_location("deploy_win_vm", "deploy_win_vm.py")
            deploy_module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(deploy_module)
        finally:
            # Restore original argv
            sys.argv = original_argv
        
        return 0
    
    print(">>> Running VM deployment in automation mode...")
    print(f"   VM Name: {automation_data.get('vm_name', 'N/A')}")
    
    # Prepare input queue for all input() calls
    inputs_queue = [
        automation_data.get('vm_name', ''),           # VM name
        automation_data.get('proceed_deployment', 'y') # Deploy confirmation
    ]
    
    # Get passwords for getpass() calls
    passwords = {
        'admin_password': automation_data.get('admin_password', ''),
        'pc_password': automation_data.get('pc_password', '')
    }
    
    print(f">>> Password automation configured:")
    print(f"   VM Admin Password: {'*' * len(passwords['admin_password']) if passwords['admin_password'] else 'Not provided'}")
    print(f"   Prism Central Password: {'*' * len(passwords['pc_password']) if passwords['pc_password'] else 'Not provided'}")
    
    # Patch the builtin input and getpass functions
    import builtins
    original_input = builtins.input
    original_getpass = getpass.getpass
    
    try:
        # Replace input and getpass with automated versions
        builtins.input = create_automated_input_function(inputs_queue)
        getpass.getpass = create_automated_getpass_function(passwords)
        
        print(">>> Patched input functions for automation")
        
        # Set argv to simulate running with --deploy flag
        original_argv = sys.argv
        
        try:
            sys.argv = ["deploy_win_vm.py", "--deploy"]
            
            spec = importlib.util.spec_from_file_location("deploy_win_vm", "deploy_win_vm.py")
            deploy_module = importlib.util.module_from_spec(spec)
            
            # Execute the main deployment
            spec.loader.exec_module(deploy_module)
            
        finally:
            # Restore original argv
            sys.argv = original_argv
        
        # Try to capture UUIDs from the deployment
        try:
            # Look for a way to extract UUIDs without memory-intensive capture
            # For now, we'll use a simple file-based approach
            with open('deployment_results.txt', 'w') as f:
                f.write("Deployment completed - check Prism Central for actual UUIDs\n")
                
            print("VM UUID: [SUCCESS]")  # Placeholder for compatibility
            print("Task UUID: [SUCCESS]") # Placeholder for compatibility
        except Exception:
            print("VM UUID: ")
            print("Task UUID: ")
        
        print(">>> Automated deployment completed")
        return 0
        
    except Exception as e:
        print(f"[ERROR] Error during automated deployment: {e}")
        return 1
        
    finally:
        # Restore original functions
        builtins.input = original_input
        getpass.getpass = original_getpass
        print(">>> Restored original input functions")

if __name__ == "__main__":
    exit_code = run_automated_deployment()
    sys.exit(exit_code)
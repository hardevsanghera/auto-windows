#!/usr/bin/env python3
"""
VM Deployment Automation Wrapper - Enhanced Version
Uses function patching to provide automated inputs to all prompts
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
        import sys
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
    original_print = builtins.print
    
    # Capture output to extract UUIDs
    vm_uuid = None
    task_uuid = None
    
    def capture_print(*args, **kwargs):
        """Capture print statements to extract UUIDs"""
        nonlocal vm_uuid, task_uuid
        
        # Join all arguments to create the full message
        message = ' '.join(str(arg) for arg in args)
        
        # Debug: Show all print messages
        if any(uuid_keyword in message for uuid_keyword in ["VM UUID", "Task UUID", "UUID:"]):
            print(f"[DEBUG] Captured print: {repr(message)}")
        
        # Look for UUID patterns in the output
        if "VM UUID:" in message:
            import re
            match = re.search(r'VM UUID:\s*([a-fA-F0-9-]+)', message)
            if match:
                vm_uuid = match.group(1)
                print(f"[DEBUG] VM UUID matched: {vm_uuid}")
            else:
                print(f"[DEBUG] VM UUID not matched in: {repr(message)}")
        
        if "Task UUID:" in message:
            import re
            match = re.search(r'Task UUID:\s*([a-fA-F0-9-]+)', message)
            if match:
                task_uuid = match.group(1)
                print(f"[DEBUG] Task UUID matched: {task_uuid}")
            else:
                print(f"[DEBUG] Task UUID not matched in: {repr(message)}")
        
        # Call original print
        return original_print(*args, **kwargs)
    
    try:
        # Replace input, getpass, and print with automated/captured versions
        builtins.input = create_automated_input_function(inputs_queue)
        getpass.getpass = create_automated_getpass_function(passwords)
        builtins.print = capture_print
        
        print(">>> Patched input functions for automation")
        
        # Import and run the deployment script with patched functions
        # We need to simulate command line arguments for --deploy mode
        import sys
        original_argv = sys.argv
        
        try:
            # Set argv to simulate running with --deploy flag
            sys.argv = ["deploy_win_vm.py", "--deploy"]
            print("[DEBUG] About to execute deploy_win_vm.py --deploy")
            
            spec = importlib.util.spec_from_file_location("deploy_win_vm", "deploy_win_vm.py")
            deploy_module = importlib.util.module_from_spec(spec)
            
            # Execute the main deployment
            print("[DEBUG] Executing deploy_win_vm module")
            spec.loader.exec_module(deploy_module)
            print("[DEBUG] deploy_win_vm module execution completed")
        finally:
            # Restore original argv
            sys.argv = original_argv
        
        # Output the captured UUIDs in the format expected by PowerShell
        print(f"[DEBUG] vm_uuid captured: {vm_uuid}")
        print(f"[DEBUG] task_uuid captured: {task_uuid}")
        
        if vm_uuid:
            print(f"VM UUID: {vm_uuid}")
        else:
            print("VM UUID: ")
            
        if task_uuid:
            print(f"Task UUID: {task_uuid}")  
        else:
            print("Task UUID: ")
        
        print(">>> Automated deployment completed")
        return 0
        
    except Exception as e:
        import traceback
        print(f"[ERROR] Error during automated deployment: {e}")
        print(f"[ERROR] Exception type: {type(e).__name__}")
        print(f"[ERROR] Traceback: {traceback.format_exc()}")
        return 1
        
    finally:
        # Restore original functions
        builtins.input = original_input
        getpass.getpass = original_getpass
        builtins.print = original_print
        print(">>> Restored original input functions")

if __name__ == "__main__":
    exit_code = run_automated_deployment()
    sys.exit(exit_code)
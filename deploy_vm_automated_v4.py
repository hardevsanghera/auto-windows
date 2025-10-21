#!/usr/bin/env python3
"""
VM Deployment Automation Wrapper - Enhanced UUID Capture Version
Uses function patching for inputs and file-based UUID extraction
"""

import os
import sys
import json
import importlib.util
import getpass
import re
import subprocess
import tempfile

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

def extract_uuids_from_output(output_text):
    """Extract VM UUID and Task UUID from deployment output"""
    vm_uuid = ""
    task_uuid = ""
    
    try:
        # Look for UUID patterns in the output
        uuid_pattern = r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
        
        lines = output_text.split('\n')
        for line in lines:
            if 'VM UUID:' in line:
                match = re.search(uuid_pattern, line)
                if match:
                    vm_uuid = match.group(0)
            elif 'Task UUID:' in line:
                match = re.search(uuid_pattern, line)
                if match:
                    task_uuid = match.group(0)
    except Exception as e:
        print(f"[DEBUG] Error extracting UUIDs: {e}")
    
    return vm_uuid, task_uuid

def run_automated_deployment():
    """Run VM deployment with automated inputs using subprocess for UUID capture"""
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
    
    # Prepare automation inputs file
    automation_inputs = [
        automation_data.get('vm_name', ''),           # VM name
        'y',                                          # Deploy confirmation
        automation_data.get('admin_password', ''),    # VM Admin password
        automation_data.get('admin_password', ''),    # VM Admin password confirmation
        automation_data.get('pc_password', '')        # Prism Central password
    ]
    
    print(f">>> Password automation configured:")
    print(f"   VM Admin Password: {'*' * len(automation_data.get('admin_password', '')) if automation_data.get('admin_password') else 'Not provided'}")
    print(f"   Prism Central Password: {'*' * len(automation_data.get('pc_password', '')) if automation_data.get('pc_password') else 'Not provided'}")
    
    try:
        # Create a temporary file with automation inputs
        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.txt') as f:
            for input_line in automation_inputs:
                f.write(input_line + '\n')
            input_file = f.name
        
        # Run the deployment script using subprocess with input redirection
        try:
            result = subprocess.run(
                [sys.executable, 'deploy_win_vm.py', '--deploy'],
                input='\n'.join(automation_inputs) + '\n',
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )
            
            output = result.stdout
            error = result.stderr
            
            # Extract UUIDs from the output
            vm_uuid, task_uuid = extract_uuids_from_output(output)
            
            print(">>> Deployment subprocess completed")
            
            # Output the results
            if vm_uuid:
                print(f"VM UUID: {vm_uuid}")
            else:
                print("VM UUID: ")
                
            if task_uuid:
                print(f"Task UUID: {task_uuid}")
            else:
                print("Task UUID: ")
            
            # Also print any errors if they occurred
            if error:
                print(f"[DEBUG] Stderr output: {error}")
            
            # Return the subprocess exit code
            return result.returncode
            
        except subprocess.TimeoutExpired:
            print("[ERROR] Deployment timed out after 5 minutes")
            return 1
        except Exception as e:
            print(f"[ERROR] Error running deployment subprocess: {e}")
            return 1
        
        finally:
            # Clean up temp file
            try:
                os.unlink(input_file)
            except:
                pass
        
    except Exception as e:
        print(f"[ERROR] Error during automated deployment: {e}")
        return 1

if __name__ == "__main__":
    exit_code = run_automated_deployment()
    sys.exit(exit_code)
#!/usr/bin/env python3
"""
VM Deployment Automation Wrapper
Provides automated input to the deploy_win_vm.py script when running in automation mode
"""

import os
import sys
import json
import subprocess
import time

def get_automation_inputs():
    """
    Read automation inputs from the specified file
    """
    automation_file = os.environ.get('VM_AUTOMATION_FILE')
    if not automation_file or not os.path.exists(automation_file):
        return None
    
    try:
        with open(automation_file, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"❌ Error reading automation file: {e}")
        return None

def run_automated_deployment():
    """
    Run VM deployment with automated inputs
    """
    automation_data = get_automation_inputs()
    
    if not automation_data:
        print("❌ No automation data found. Running in interactive mode.")
        # Fall back to normal deployment
        return subprocess.run([sys.executable, "deploy_win_vm.py", "--deploy"])
    
    print("🤖 Running VM deployment in automation mode...")
    print(f"   VM Name: {automation_data.get('vm_name', 'N/A')}")
    
    # Prepare the inputs as they would be entered interactively
    # Order based on deploy_win_vm.py prompts:
    # 1. VM name (input line 523)
    # 2. Admin password (getpass - handled by subprocess)  
    # 3. Confirm password (getpass - handled by subprocess)
    # 4. Deploy confirmation (input line 623)
    # 5. API password (getpass - handled by subprocess)
    
    inputs = [
        automation_data.get('vm_name', ''),           # VM name prompt
        automation_data.get('proceed_deployment', 'y'), # Deploy confirmation 
        ''  # Extra newline for safety
    ]
    
    # Note: getpass() calls don't read from stdin, so we can't automate those
    # The subprocess will handle password prompts through terminal interaction
    input_string = '\n'.join(inputs) + '\n'
    
    print(f"📝 Automation inputs prepared:")
    print(f"   VM Name: {automation_data.get('vm_name', '')}")
    print(f"   Deploy Confirmation: {automation_data.get('proceed_deployment', 'y')}")
    
    try:
        # Set environment variables to handle console encoding properly
        env = os.environ.copy()
        env['PYTHONIOENCODING'] = 'cp1252:replace'  # Windows console encoding with error handling
        env['PYTHONLEGACYWINDOWSSTDIO'] = '1'
        
        # Run the deployment script with automated inputs
        process = subprocess.Popen(
            [sys.executable, "deploy_win_vm.py", "--deploy"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=0,  # Unbuffered
            env=env,
            encoding='utf-8',
            errors='replace'  # Replace problematic characters instead of failing
        )
        
        # Send inputs and get output
        stdout, stderr = process.communicate(input=input_string, timeout=300)  # 5 minute timeout
        
        # Print the output
        if stdout:
            print(stdout)
        if stderr:
            print(stderr, file=sys.stderr)
        
        return process
        
    except subprocess.TimeoutExpired:
        print("❌ Deployment timed out after 5 minutes")
        process.kill()
        return None
    except Exception as e:
        print(f"❌ Error during automated deployment: {e}")
        return None

if __name__ == "__main__":
    result = run_automated_deployment()
    if result:
        sys.exit(result.returncode)
    else:
        sys.exit(1)
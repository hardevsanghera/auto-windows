#!/usr/bin/env python3
"""
Fix Unicode encoding issues in deploy_win_vm.py
Replace Unicode emoji characters with ASCII equivalents
"""

import re
import shutil
import os

def fix_unicode_in_file(file_path):
    """
    Replace Unicode emoji characters with ASCII equivalents
    """
    # Read the file
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Create backup
    backup_path = file_path + '.backup'
    shutil.copy2(file_path, backup_path)
    print(f"Created backup: {backup_path}")
    
    # Define Unicode to ASCII mappings
    unicode_replacements = {
        '✅': '[OK]',
        '❌': '[ERROR]', 
        '💻': '[VM]',
        '🔐': '[PASS]',
        '🔧': '[BUILD]',
        '📄': '[INFO]',
        '🚀': '[DEPLOY]',
        '🌐': '[API]',
        '📊': '[STATUS]'
    }
    
    # Apply replacements
    original_content = content
    for unicode_char, ascii_replacement in unicode_replacements.items():
        content = content.replace(unicode_char, ascii_replacement)
    
    # Write the modified content back
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    # Count replacements
    changes_made = 0
    for unicode_char in unicode_replacements:
        changes_made += original_content.count(unicode_char)
    
    print(f"Fixed {changes_made} Unicode characters in {file_path}")
    
    return changes_made

def main():
    deploy_script = "temp/repos/deploy_win_vm_v1/deploy_win_vm.py"
    
    if not os.path.exists(deploy_script):
        print(f"Error: {deploy_script} not found")
        return False
    
    print("Fixing Unicode encoding issues...")
    changes = fix_unicode_in_file(deploy_script)
    
    if changes > 0:
        print(f"✓ Successfully fixed {changes} Unicode characters")
        print("✓ Script should now work with Windows console encoding")
        return True
    else:
        print("No Unicode characters found to fix")
        return False

if __name__ == "__main__":
    main()
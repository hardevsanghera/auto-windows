# Password Management Functions for Auto-Windows
# Provides secure password caching and management

function Get-PasswordCacheFile {
    <#
    .SYNOPSIS
    Get the path to the password cache file with enhanced directory creation and validation
    #>
    $cacheDir = Join-Path $env:APPDATA "AutoWindows"
    
    # Enhanced cache directory creation with proper error handling
    try {
        if (-not (Test-Path $cacheDir)) {
            Write-Host "DEBUG: Creating cache directory: $cacheDir" -ForegroundColor Magenta
            New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
            
            # Verify directory was created successfully
            if (-not (Test-Path $cacheDir)) {
                throw "Failed to create cache directory: $cacheDir"
            }
            
            Write-Host "DEBUG: Cache directory created successfully" -ForegroundColor Green
        } else {
            Write-Host "DEBUG: Cache directory exists: $cacheDir" -ForegroundColor Cyan
        }
        
        # Test write permissions
        $testFile = Join-Path $cacheDir "test_permissions.tmp"
        try {
            "test" | Out-File -FilePath $testFile -Force
            Remove-Item -Path $testFile -Force -ErrorAction SilentlyContinue
            Write-Host "DEBUG: Cache directory write permissions verified" -ForegroundColor Green
        } catch {
            throw "No write permissions for cache directory: $cacheDir - $($_.Exception.Message)"
        }
        
    } catch {
        Write-Warning "Cache directory setup failed: $($_.Exception.Message)"
        Write-Host "DEBUG: Falling back to temp directory for password cache" -ForegroundColor Yellow
        $cacheDir = $env:TEMP
    }
    
    $cacheFile = Join-Path $cacheDir "prism_credentials.dat"
    Write-Host "DEBUG: Using cache file: $cacheFile" -ForegroundColor Magenta
    return $cacheFile
}

function Save-CachedPassword {
    <#
    .SYNOPSIS
    Save password securely to cache file
    
    .PARAMETER Username
    The username associated with the password
    
    .PARAMETER Password
    The password to cache (as SecureString)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Username,
        
        [Parameter(Mandatory = $true)]
        [SecureString]$Password
    )
    
    try {
        $cacheFile = Get-PasswordCacheFile
        
        # Enhanced cache file validation and corruption handling
        Write-Host "DEBUG: Cache file path: $cacheFile" -ForegroundColor Magenta
        Write-Host "DEBUG: Cache file exists: $(Test-Path $cacheFile)" -ForegroundColor Magenta
        
        # Load existing credentials or create new collection
        $credentialStore = @{}
        if (Test-Path $cacheFile) {
            try {
                Write-Host "DEBUG: Loading existing cache file" -ForegroundColor Cyan
                $credentialStore = Import-Clixml -Path $cacheFile
                
                # Validate cache file structure
                if ($credentialStore -isnot [hashtable]) {
                    throw "Cache file contains invalid data structure"
                }
                
                Write-Host "DEBUG: Cache file loaded successfully, contains $($credentialStore.Count) entries" -ForegroundColor Green
            }
            catch {
                Write-Warning "Cache file corrupted or invalid: $($_.Exception.Message)"
                Write-Host "DEBUG: Removing corrupted cache file: $cacheFile" -ForegroundColor Yellow
                try {
                    Remove-Item -Path $cacheFile -Force -ErrorAction Stop
                    Write-Host "DEBUG: Corrupted cache file removed successfully" -ForegroundColor Green
                } catch {
                    Write-Warning "Could not remove corrupted cache file: $($_.Exception.Message)"
                }
                $credentialStore = @{}
            }
        } else {
            Write-Host "DEBUG: No existing cache file found, creating new credential store" -ForegroundColor Cyan
        }
        
        # Create credential object
        $credential = New-Object System.Management.Automation.PSCredential($Username, $Password)
        
        # Add or update this user's credential
        $credentialStore[$Username] = $credential
        
        # Export entire credential store to file (encrypted with user's key)
        try {
            $credentialStore | Export-Clixml -Path $cacheFile -Force
            Write-Host "DEBUG: Credential store exported successfully to: $cacheFile" -ForegroundColor Green
            
            # Verify the file was written correctly
            if (Test-Path $cacheFile) {
                $fileSize = (Get-Item $cacheFile).Length
                Write-Host "DEBUG: Cache file written successfully ($fileSize bytes)" -ForegroundColor Green
            } else {
                throw "Cache file was not created after export"
            }
            
        } catch {
            throw "Failed to export credential store: $($_.Exception.Message)"
        }
        
        Write-Host "Password cached securely for user: $Username" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Failed to cache password: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

function Get-CachedPassword {
    <#
    .SYNOPSIS
    Retrieve cached password if available, or prompt for new password
    
    .PARAMETER Username
    The username to retrieve password for
    
    .PARAMETER ForcePrompt
    Force password prompt even if cached password exists
    
    .OUTPUTS
    SecureString password if found, $null if not found
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Username,
        
        [Parameter(Mandatory = $false)]
        [switch]$ForcePrompt
    )
    
    # Handle ForcePrompt - prompt for new password and cache it
    if ($ForcePrompt) {
        Write-Host "Enter password for user: $Username" -ForegroundColor Cyan
        $securePassword = Read-Host "Password" -AsSecureString
        
        if ($securePassword -and $securePassword.Length -gt 0) {
            # Cache the new password
            Save-CachedPassword -Username $Username -Password $securePassword
            return $securePassword
        } else {
            Write-Host "No password entered." -ForegroundColor Yellow
            return $null
        }
    }
    
    try {
        $cacheFile = Get-PasswordCacheFile
        
        Write-Host "DEBUG: Looking for cached password for user: $Username" -ForegroundColor Magenta
        Write-Host "DEBUG: Cache file path: $cacheFile" -ForegroundColor Magenta
        
        if (-not (Test-Path $cacheFile)) {
            Write-Host "DEBUG: Cache file does not exist: $cacheFile" -ForegroundColor Magenta
            return $null
        }
        
        # Enhanced cache file validation before import
        try {
            # Test if file is readable and not empty
            $fileInfo = Get-Item $cacheFile
            if ($fileInfo.Length -eq 0) {
                Write-Warning "Cache file is empty, removing: $cacheFile"
                Remove-Item $cacheFile -Force
                return $null
            }
            
            Write-Host "DEBUG: Cache file exists and is readable ($(($fileInfo.Length)) bytes)" -ForegroundColor Cyan
            
            # Import credential store from file with validation
            $credentialStore = Import-Clixml -Path $cacheFile
            Write-Host "DEBUG: Successfully imported credential store from cache file" -ForegroundColor Green
            
        } catch {
            Write-Warning "Failed to read cache file, removing corrupted file: $($_.Exception.Message)"
            try {
                Remove-Item $cacheFile -Force -ErrorAction Stop
                Write-Host "DEBUG: Corrupted cache file removed" -ForegroundColor Green
            } catch {
                Write-Warning "Could not remove corrupted cache file: $($_.Exception.Message)"
            }
            return $null
        }
        
        # Check if this is the old single-credential format
        if ($credentialStore -is [System.Management.Automation.PSCredential]) {
            # Old format - convert to new format
            $oldCredential = $credentialStore
            $credentialStore = @{}
            $credentialStore[$oldCredential.UserName] = $oldCredential
            
            # Save in new format
            $credentialStore | Export-Clixml -Path $cacheFile -Force
            Write-Host "DEBUG: Converted old credential format to new format" -ForegroundColor Magenta
        }
        
        # Look up the specific username
        if ($credentialStore.ContainsKey($Username)) {
            Write-Host "Using cached password for: $Username" -ForegroundColor Green
            $retrievedPassword = $credentialStore[$Username].Password
            
            # DEBUG: Show password details
            $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($retrievedPassword))
            Write-Host "DEBUG: Retrieved password for '$Username': '$plainPassword' (Length: $($plainPassword.Length))" -ForegroundColor Magenta
            
            return $retrievedPassword
        }
        else {
            # List available cached users for debugging
            $cachedUsers = $credentialStore.Keys -join ", "
            Write-Host "No cached password for user: $Username" -ForegroundColor Yellow
            if ($cachedUsers) {
                Write-Host "   Available cached users: $cachedUsers" -ForegroundColor Gray
            }
            Write-Host "DEBUG: Username '$Username' not found in cache keys: [$cachedUsers]" -ForegroundColor Magenta
            return $null
        }
    }
    catch {
        Write-Host "Failed to retrieve cached password: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "DEBUG: Exception details: $($_.Exception)" -ForegroundColor Magenta
        return $null
    }
}

function Remove-CachedPassword {
    <#
    .SYNOPSIS
    Remove cached password(s)
    
    .PARAMETER Username
    Specific username to remove. If not specified, all passwords are cleared.
    #>
    param(
        [string]$Username = $null
    )
    
    $cacheFile = Get-PasswordCacheFile
    
    if (-not (Test-Path $cacheFile)) {
        Write-Host "ℹ️  No password cache to clear" -ForegroundColor Cyan
        return $true
    }
    
    try {
        if ($Username) {
            # Remove specific user
            $credentialData = Import-Clixml -Path $cacheFile
            
            if ($credentialData -is [System.Management.Automation.PSCredential]) {
                # Old single-credential format
                if ($credentialData.UserName -eq $Username) {
                    Remove-Item -Path $cacheFile -Force
                    Write-Host "Password cache cleared for user: $Username" -ForegroundColor Green
                } else {
                    Write-Host "User '$Username' not found in cache" -ForegroundColor Yellow
                }
            }
            elseif ($credentialData -is [hashtable]) {
                # New multi-credential format
                if ($credentialData.ContainsKey($Username)) {
                    $credentialData.Remove($Username)
                    
                    if ($credentialData.Count -eq 0) {
                        # No users left, remove the file
                        Remove-Item -Path $cacheFile -Force
                        Write-Host "Last password removed, cache cleared" -ForegroundColor Green
                    } else {
                        # Save updated cache
                        $credentialData | Export-Clixml -Path $cacheFile -Force
                        Write-Host "Password cleared for user: $Username" -ForegroundColor Green
                    }
                } else {
                    Write-Host "User '$Username' not found in cache" -ForegroundColor Yellow
                }
            }
        } else {
            # Remove all passwords
            Remove-Item -Path $cacheFile -Force
            Write-Host "All password caches cleared" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Failed to clear password cache: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    return $true
}

function Get-AdminPassword {
    <#
    .SYNOPSIS
    Get admin password with caching support
    
    .PARAMETER Username
    The username to get password for
    
    .PARAMETER UseCache
    Whether to use cached password if available
    
    .PARAMETER SaveToCache
    Whether to save password to cache after entry
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Username,
        
        [Parameter(Mandatory = $false)]
        [switch]$UseCache,
        
        [Parameter(Mandatory = $false)]
        [switch]$SaveToCache
    )
    
    Write-Host "DEBUG: Get-AdminPassword called for username: '$Username'" -ForegroundColor Magenta
    Write-Host "DEBUG: UseCache: $UseCache, SaveToCache: $SaveToCache" -ForegroundColor Magenta
    
    # Try to get cached password first (default behavior)
    if (-not $UseCache.IsPresent -or $UseCache) {
        Write-Host "DEBUG: Attempting to get cached password..." -ForegroundColor Magenta
        $cachedPassword = Get-CachedPassword -Username $Username
        if ($cachedPassword) {
            $plainCached = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($cachedPassword))
            Write-Host "DEBUG: Found cached password for '$Username': '$plainCached' (Length: $($plainCached.Length))" -ForegroundColor Magenta
            return $cachedPassword
        } else {
            Write-Host "DEBUG: No cached password found for '$Username'" -ForegroundColor Magenta
        }
    }
    
    # Prompt for password
    Write-Host "Enter password for $Username (will be cached for future use):" -ForegroundColor Cyan
    $password = Read-Host -AsSecureString
    
    # Validate password is not empty
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
    Write-Host "DEBUG: Entered password for '$Username': '$plainPassword' (Length: $($plainPassword.Length))" -ForegroundColor Magenta
    if ([string]::IsNullOrEmpty($plainPassword)) {
        Write-Host "Password cannot be empty" -ForegroundColor Red
        return $null
    }
    
    # Save to cache by default
    if (-not $SaveToCache.IsPresent -or $SaveToCache) {
        Write-Host "DEBUG: Saving password to cache..." -ForegroundColor Magenta
        Save-CachedPassword -Username $Username -Password $password | Out-Null
    }
    
    return $password
}

function ConvertTo-PlainText {
    <#
    .SYNOPSIS
    Convert SecureString to plain text (use carefully)
    
    .PARAMETER SecurePassword
    The SecureString to convert
    #>
    param(
        [Parameter(Mandatory = $true)]
        [SecureString]$SecurePassword
    )
    
    $plainText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword))
    Write-Host "DEBUG: ConvertTo-PlainText result: '$plainText' (Length: $($plainText.Length))" -ForegroundColor Magenta
    return $plainText
}

function Show-PasswordCacheStatus {
    <#
    .SYNOPSIS
    Show current password cache status
    #>
    $cacheFile = Get-PasswordCacheFile
    
    Write-Host "Password Cache Status:" -ForegroundColor Yellow
    Write-Host "Cache File: $cacheFile" -ForegroundColor Gray
    
    if (Test-Path $cacheFile) {
        try {
            $credentialData = Import-Clixml -Path $cacheFile
            $fileInfo = Get-Item $cacheFile
            
            # Handle both old single-credential and new multi-credential formats
            if ($credentialData -is [System.Management.Automation.PSCredential]) {
                Write-Host "Password cached for user: $($credentialData.UserName)" -ForegroundColor Green
            }
            elseif ($credentialData -is [hashtable]) {
                Write-Host "Passwords cached for $($credentialData.Count) user(s):" -ForegroundColor Green
                foreach ($username in $credentialData.Keys) {
                    Write-Host "  - $username" -ForegroundColor Green
                }
            }
            else {
                Write-Host "Unknown cache format" -ForegroundColor Yellow
            }
            
            Write-Host "  Created: $($fileInfo.CreationTime)" -ForegroundColor Gray
            Write-Host "  Last Modified: $($fileInfo.LastWriteTime)" -ForegroundColor Gray
        }
        catch {
            Write-Host "Cache file exists but is corrupted: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "INFO: No passwords currently cached" -ForegroundColor Cyan
    }
}

function Get-VMCredentials {
    <#
    .SYNOPSIS
    Get VM credentials with enhanced caching and validation
    
    .DESCRIPTION
    Centralized function to get VM administrator credentials with smart caching,
    cache validation, and consistent error handling across all scripts.
    
    .PARAMETER ForcePrompt
    Force password prompt even if cached password exists
    
    .PARAMETER ValidateCredentials
    Test credentials against the VM before returning them
    
    .PARAMETER VMIPAddress
    IP address to test credentials against (required if ValidateCredentials is true)
    #>
    param(
        [switch]$ForcePrompt,
        [switch]$ValidateCredentials,
        [string]$VMIPAddress
    )
    
    Write-Host "`nGetting VM Credentials..." -ForegroundColor Cyan
    
    if (-not $ForcePrompt) {
        # Try to get cached VM administrator password
        $vmPassword = Get-CachedPassword -Username "vm-administrator"
        
        if ($vmPassword) {
            Write-Host "Using cached password for: vm-administrator" -ForegroundColor Green
            
            # Handle both SecureString and plain text passwords
            if ($vmPassword -is [System.Security.SecureString]) {
                $securePassword = $vmPassword
            } else {
                $securePassword = ConvertTo-SecureString $vmPassword -AsPlainText -Force
            }
            
            $credential = New-Object System.Management.Automation.PSCredential("Administrator", $securePassword)
            
            # Validate credentials if requested
            if ($ValidateCredentials -and $VMIPAddress) {
                Write-Host "Validating cached credentials..." -ForegroundColor Yellow
                if (Test-VMCredentials -Credential $credential -VMIPAddress $VMIPAddress) {
                    Write-Host "Cached credentials validated successfully" -ForegroundColor Green
                    return $credential
                } else {
                    Write-Host "Cached credentials failed validation, prompting for new password" -ForegroundColor Red
                    # Remove invalid cached password
                    Remove-CachedPassword -Username "vm-administrator"
                }
            } else {
                return $credential
            }
        }
    }
    
    # Prompt for new credentials
    Write-Host "[INFO] Getting VM administrator credentials..." -ForegroundColor Yellow
    $credential = Get-Credential -UserName "Administrator" -Message "Enter credentials for VM Administrator"
    
    if ($credential) {
        # Cache the new password
        Save-CachedPassword -Username "vm-administrator" -Password $credential.Password
        Write-Host "New password cached for future use" -ForegroundColor Green
    }
    
    return $credential
}

function Test-VMCredentials {
    <#
    .SYNOPSIS
    Test VM credentials by attempting a simple PowerShell connection
    
    .PARAMETER Credential
    Credentials to test
    
    .PARAMETER VMIPAddress
    VM IP address to test against
    #>
    param(
        [System.Management.Automation.PSCredential]$Credential,
        [string]$VMIPAddress
    )
    
    try {
        # Test with a simple WinRM connection
        $testSession = New-PSSession -ComputerName $VMIPAddress -Credential $Credential -ErrorAction Stop
        if ($testSession) {
            Remove-PSSession $testSession -ErrorAction SilentlyContinue
            return $true
        }
    }
    catch {
        Write-Debug "Credential validation failed: $($_.Exception.Message)"
        return $false
    }
    
    return $false
}
# Password Management Functions for Auto-Windows
# Provides secure password caching and management

function Get-PasswordCacheFile {
    <#
    .SYNOPSIS
    Get the path to the password cache file
    #>
    $cacheDir = Join-Path $env:APPDATA "AutoWindows"
    if (-not (Test-Path $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }
    return Join-Path $cacheDir "prism_credentials.dat"
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
        
        # Load existing credentials or create new collection
        $credentialStore = @{}
        if (Test-Path $cacheFile) {
            try {
                $credentialStore = Import-Clixml -Path $cacheFile
            }
            catch {
                # If corrupted, start fresh
                $credentialStore = @{}
            }
        }
        
        # Create credential object
        $credential = New-Object System.Management.Automation.PSCredential($Username, $Password)
        
        # Add or update this user's credential
        $credentialStore[$Username] = $credential
        
        # Export entire credential store to file (encrypted with user's key)
        $credentialStore | Export-Clixml -Path $cacheFile -Force
        
        Write-Host "✓ Password cached securely for user: $Username" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "⚠️  Failed to cache password: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

function Get-CachedPassword {
    <#
    .SYNOPSIS
    Retrieve cached password if available
    
    .PARAMETER Username
    The username to retrieve password for
    
    .OUTPUTS
    SecureString password if found, $null if not found
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Username
    )
    
    try {
        $cacheFile = Get-PasswordCacheFile
        
        if (-not (Test-Path $cacheFile)) {
            return $null
        }
        
        # Import credential store from file
        $credentialStore = Import-Clixml -Path $cacheFile
        
        # Check if this is the old single-credential format
        if ($credentialStore -is [System.Management.Automation.PSCredential]) {
            # Old format - convert to new format
            $oldCredential = $credentialStore
            $credentialStore = @{}
            $credentialStore[$oldCredential.UserName] = $oldCredential
            
            # Save in new format
            $credentialStore | Export-Clixml -Path $cacheFile -Force
        }
        
        # Look up the specific username
        if ($credentialStore.ContainsKey($Username)) {
            Write-Host "✓ Using cached password for: $Username" -ForegroundColor Green
            return $credentialStore[$Username].Password
        }
        else {
            # List available cached users for debugging
            $cachedUsers = $credentialStore.Keys -join ", "
            Write-Host "⚠️  No cached password for user: $Username" -ForegroundColor Yellow
            if ($cachedUsers) {
                Write-Host "   Available cached users: $cachedUsers" -ForegroundColor Gray
            }
            return $null
        }
    }
    catch {
        Write-Host "⚠️  Failed to retrieve cached password: $($_.Exception.Message)" -ForegroundColor Yellow
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
                    Write-Host "✓ Password cache cleared for user: $Username" -ForegroundColor Green
                } else {
                    Write-Host "⚠️  User '$Username' not found in cache" -ForegroundColor Yellow
                }
            }
            elseif ($credentialData -is [hashtable]) {
                # New multi-credential format
                if ($credentialData.ContainsKey($Username)) {
                    $credentialData.Remove($Username)
                    
                    if ($credentialData.Count -eq 0) {
                        # No users left, remove the file
                        Remove-Item -Path $cacheFile -Force
                        Write-Host "✓ Last password removed, cache cleared" -ForegroundColor Green
                    } else {
                        # Save updated cache
                        $credentialData | Export-Clixml -Path $cacheFile -Force
                        Write-Host "✓ Password cleared for user: $Username" -ForegroundColor Green
                    }
                } else {
                    Write-Host "⚠️  User '$Username' not found in cache" -ForegroundColor Yellow
                }
            }
        } else {
            # Remove all passwords
            Remove-Item -Path $cacheFile -Force
            Write-Host "✓ All password caches cleared" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "❌ Failed to clear password cache: $($_.Exception.Message)" -ForegroundColor Red
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
    
    # Try to get cached password first (default behavior)
    if (-not $UseCache.IsPresent -or $UseCache) {
        $cachedPassword = Get-CachedPassword -Username $Username
        if ($cachedPassword) {
            return $cachedPassword
        }
    }
    
    # Prompt for password
    Write-Host "🔐 Enter password for $Username (will be cached for future use):" -ForegroundColor Cyan
    $password = Read-Host -AsSecureString
    
    # Validate password is not empty
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
    if ([string]::IsNullOrEmpty($plainPassword)) {
        Write-Host "❌ Password cannot be empty" -ForegroundColor Red
        return $null
    }
    
    # Save to cache by default
    if (-not $SaveToCache.IsPresent -or $SaveToCache) {
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
    
    return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword))
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
                Write-Host "✓ Password cached for user: $($credentialData.UserName)" -ForegroundColor Green
            }
            elseif ($credentialData -is [hashtable]) {
                Write-Host "✓ Passwords cached for $($credentialData.Count) user(s):" -ForegroundColor Green
                foreach ($username in $credentialData.Keys) {
                    Write-Host "  - $username" -ForegroundColor Green
                }
            }
            else {
                Write-Host "⚠️  Unknown cache format" -ForegroundColor Yellow
            }
            
            Write-Host "  Created: $($fileInfo.CreationTime)" -ForegroundColor Gray
            Write-Host "  Last Modified: $($fileInfo.LastWriteTime)" -ForegroundColor Gray
        }
        catch {
            Write-Host "⚠️  Cache file exists but is corrupted: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "ℹ️  No passwords currently cached" -ForegroundColor Cyan
    }
}
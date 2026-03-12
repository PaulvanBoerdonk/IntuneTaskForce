<#
.SYNOPSIS
    Connects to Microsoft Graph with the required scopes for IntuneTaskForce operations.

.DESCRIPTION
    This function acts as a wrapper around Connect-MgGraph. It checks if an active 
    connection exists AND if all required scopes are present. If scopes are missing, 
    it initiates a fresh connection.
#>
function Connect-IntuneTaskForce {
    [CmdletBinding()]
    param (
        [string[]]$Scopes = @(
            "DeviceManagementManagedDevices.Read.All",
            "DeviceManagementManagedDevices.PrivilegedOperations.All",
            "Group.Read.All",
            "DeviceManagementServiceConfig.Read.All",
            "Device.ReadWrite.All",
            "BitLockerKey.Read.All",
            "DeviceLocalCredential.Read.All"
        )
    )

    try {
        $currentContext = Get-MgContext -ErrorAction SilentlyContinue
        
        if ($null -ne $currentContext) {
            # Check if our current session has all the scopes we need
            $missingScopes = $Scopes | Where-Object { $_ -notin $currentContext.Scopes }
            
            if ($missingScopes.Count -eq 0) {
                Write-Host "✅ Already connected to Microsoft Graph with all required scopes." -ForegroundColor Green
                return
            }
            else {
                Write-Host "⚠️ Connected, but missing required scopes. Requesting new permissions..." -ForegroundColor Yellow
                # We don't return here, so it continues to Connect-MgGraph below
            }
        }
        else {
            Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
        }
        
        # Connect while suppressing welcome messages, Wam warnings, and output
        $null = Connect-MgGraph -Scopes $Scopes -NoWelcome -WarningAction SilentlyContinue -ErrorAction Stop
        
        # Verify the connection was actually successful
        $newContext = Get-MgContext -ErrorAction SilentlyContinue
        if ($null -ne $newContext) {
            Write-Host "✅ Successfully connected as $($newContext.Account)." -ForegroundColor Green
        }
        else {
            Write-Warning "Authentication was canceled or failed."
        }
    }
    catch {
        Write-Warning "Authentication was canceled or an error occurred."
    }
}
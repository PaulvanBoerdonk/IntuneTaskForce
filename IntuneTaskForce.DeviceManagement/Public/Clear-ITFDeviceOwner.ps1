<#
.SYNOPSIS
    Removes the Primary User in Intune and the Registered Owner in Entra ID.

.DESCRIPTION
    When an Intune device is wiped and repurposed as a Shared Device (Self-Deploying), 
    the original user often remains attached as the Registered Owner in Entra ID.
    This function finds the device in both Intune and Entra ID and completely 
    strips all user ownership associations using native Microsoft Graph PowerShell cmdlets.

.PARAMETER DeviceName
    The Intune Display Name of the device you want to clear.

.EXAMPLE
    Clear-ITFDeviceOwner -DeviceName "WPS-12345"
    Finds the device 'WPS-12345', removes the Intune Primary User, and removes the Entra ID Owner.

.EXAMPLE
    Clear-ITFDeviceOwner -DeviceName "WPS-12345" -WhatIf
    Simulates the ownership removal process safely.
#>
function Clear-ITFDeviceOwner {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName
    )

    try {
        Write-Verbose "Searching for device '$DeviceName' in Intune..."
        
        # 1. Get the device from Intune
        $intuneDevices = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$DeviceName'" -ErrorAction Stop

        if ($null -eq $intuneDevices -or $intuneDevices.Count -eq 0) {
            Write-Warning "Could not find device '$DeviceName' in Intune."
            return
        }
        
        foreach ($intuneDevice in $intuneDevices) {
            
            if ($PSCmdlet.ShouldProcess("Device: $($intuneDevice.DeviceName)", "Strip Intune Primary User and Entra ID Registered Owner")) {
                
                Write-Host "Processing Device: $($intuneDevice.DeviceName) ($($intuneDevice.Id))" -ForegroundColor Cyan
                
                # --- INTUNE: REMOVE PRIMARY USER ---
                try {
                    Write-Host "  -> Checking Intune Primary User..."
                    
                    # Native SDK call to get the users attached to the managed device
                    $intuneUsers = Get-MgDeviceManagementManagedDeviceUser -ManagedDeviceId $intuneDevice.Id -ErrorAction Stop
                    
                    if ($null -ne $intuneUsers -and $intuneUsers.Count -gt 0) {
                        foreach ($user in $intuneUsers) {
                            Write-Host "     Removing Intune Primary User: $($user.UserPrincipalName)" -ForegroundColor Yellow
                            
                            # Native SDK call to remove the user mapping reference
                            Remove-MgDeviceManagementManagedDeviceUserByRef -ManagedDeviceId $intuneDevice.Id -UserId $user.Id -ErrorAction Stop
                        }
                    }
                    else {
                        Write-Host "     No Intune Primary User found. Already clear." -ForegroundColor Green
                    }
                }
                catch {
                    Write-Warning "  -> Failed to remove Intune Primary User: $($_.Exception.Message)"
                }

                # --- ENTRA ID: REMOVE REGISTERED OWNER ---
                try {
                    Write-Host "  -> Checking Entra ID Registered Owner..."
                    
                    if ([string]::IsNullOrEmpty($intuneDevice.AzureAdDeviceId)) {
                        Write-Warning "     Device is not joined to Entra ID (AzureAdDeviceId is empty)."
                        continue
                    }

                    # Translate the AzureAdDeviceId (Guid) to the internal Entra ID Object ID
                    $entraDevice = Get-MgDevice -Filter "deviceId eq '$($intuneDevice.AzureAdDeviceId)'" -ErrorAction Stop
                    
                    if ($null -eq $entraDevice) {
                        Write-Warning "     Could not locate the device in Entra ID. It might have been deleted."
                        continue
                    }

                    $entraObjectId = $entraDevice.Id
                    $owners = Get-MgDeviceRegisteredOwner -DeviceId $entraObjectId -ErrorAction Stop

                    if ($null -ne $owners -and $owners.Count -gt 0) {
                        foreach ($owner in $owners) {
                            
                            # Native SDK call to get the UPN (defaults to ID if it's not a user, e.g., a service principal)
                            $ownerName = $owner.Id
                            $ownerDetails = Get-MgUser -UserId $owner.Id -ErrorAction SilentlyContinue
                            if ($null -ne $ownerDetails -and -not [string]::IsNullOrEmpty($ownerDetails.UserPrincipalName)) {
                                $ownerName = $ownerDetails.UserPrincipalName
                            }
                            
                            Write-Host "     Removing Entra ID Owner: $ownerName" -ForegroundColor Yellow
                            Remove-MgDeviceRegisteredOwnerByRef -DeviceId $entraObjectId -DirectoryObjectId $owner.Id -ErrorAction Stop
                        }
                    }
                    else {
                        Write-Host "     No Entra ID Registered Owner found. Already clear." -ForegroundColor Green
                    }
                }
                catch {
                    Write-Warning "  -> Failed to remove Entra ID Owner: $($_.Exception.Message)"
                }
                
                Write-Host "  ✅ Ownership cleared for $($intuneDevice.DeviceName)!" -ForegroundColor Green
            }
        }
    }
    catch {
        if ($_.Exception.Message -match "Authentication needed" -or $_.FullyQualifiedErrorId -match "Authentication") {
            Write-Warning "You are currently not authenticated to Microsoft Graph."
            Write-Host "Please run 'Connect-IntuneTaskForce' to authenticate first." -ForegroundColor Yellow
        }
        else {
            Write-Error "An error occurred: $($_.Exception.Message)"
        }
    }
}
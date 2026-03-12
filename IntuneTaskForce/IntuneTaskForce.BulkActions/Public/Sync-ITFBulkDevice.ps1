<#
.SYNOPSIS
    Triggers a bulk sync for Intune managed devices based on a group or a name prefix.

.DESCRIPTION
    This function retrieves devices from Microsoft Intune and triggers a device sync action.
    It bypasses the 100-device GUI limit. You can target devices by providing a prefix for 
    the device name, or by providing an Entra ID (Azure AD) group name.

.PARAMETER DeviceNamePrefix
    The prefix of the device names to sync.

.PARAMETER GroupName
    The name of the Entra ID group containing the devices to sync.

.EXAMPLE
    Sync-ITFBulkDevice -DeviceNamePrefix "WIN-"
    Syncs all Intune devices where the name starts with 'WIN-'.

.EXAMPLE
    Sync-ITFBulkDevice -GroupName "Workstations-Device-Group"
    Syncs all Intune managed devices that are members of the specified Entra ID group.
#>
function Sync-ITFBulkDevice {
    [CmdletBinding(DefaultParameterSetName = 'Prefix')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Prefix')]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceNamePrefix,

        [Parameter(Mandatory = $true, ParameterSetName = 'Group')]
        [ValidateNotNullOrEmpty()]
        [string]$GroupName
    )

    try {
        $devicesToSync = @()

        if ($PSCmdlet.ParameterSetName -eq 'Prefix') {
            Write-Verbose "Fetching devices with a name starting with '$DeviceNamePrefix'..."
            # Added -ErrorAction Stop to cleanly catch unauthenticated states
            $devicesToSync = Get-MgDeviceManagementManagedDevice -Filter "startswith(deviceName, '$DeviceNamePrefix')" -All -ErrorAction Stop
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Group') {
            Write-Verbose "Fetching Entra ID group '$GroupName'..."
            $group = Get-MgGroup -Filter "displayName eq '$GroupName'" -ErrorAction Stop
            
            if (-not $group) {
                Write-Error "Group '$GroupName' not found in Entra ID."
                return
            }

            $groupMembers = Get-MgGroupMember -GroupId $group.Id -All -ErrorAction Stop
            
            $entraDeviceIds = foreach ($member in $groupMembers) {
                if ($member.AdditionalProperties.deviceId) {
                    $member.AdditionalProperties.deviceId
                }
            }

            if ($null -eq $entraDeviceIds -or $entraDeviceIds.Count -eq 0) {
                Write-Warning "No devices found in the group '$GroupName'."
                return
            }

            $allManagedDevices = Get-MgDeviceManagementManagedDevice -All -ErrorAction Stop
            $devicesToSync = $allManagedDevices | Where-Object { $entraDeviceIds -contains $_.AzureAdDeviceId }
        }

        if ($null -eq $devicesToSync -or $devicesToSync.Count -eq 0) {
            Write-Warning "No Intune managed devices found matching the provided criteria."
            return
        }

        Write-Host "Found $($devicesToSync.Count) device(s) to sync. Starting bulk operation..." -ForegroundColor Cyan

        $counter = 1
        foreach ($device in $devicesToSync) {
            Write-Host "[$counter/$($devicesToSync.Count)] Syncing device: $($device.DeviceName) ($($device.Id))"
            
            try {
                Sync-MgDeviceManagementManagedDevice -ManagedDeviceId $device.Id -ErrorAction Stop
            }
            catch {
                Write-Warning "Failed to sync device $($device.DeviceName). Error: $($_.Exception.Message)"
            }

            Start-Sleep -Milliseconds 150
            $counter++
        }

        Write-Host "Bulk sync completed successfully!" -ForegroundColor Green
    }
    catch {
        # Provide a clean exit if the user forgot to authenticate
        if ($_.Exception.Message -match "Authentication needed" -or $_.FullyQualifiedErrorId -match "Authentication") {
            Write-Warning "You are currently not authenticated to Microsoft Graph."
            Write-Host "Please run 'Connect-IntuneTaskForce' to authenticate first." -ForegroundColor Yellow
        }
        else {
            Write-Error "An error occurred during the bulk sync: $($_.Exception.Message)"
        }
    }
}
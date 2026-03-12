<#
.SYNOPSIS
    Finds Self-Deploying (Shared) devices that are incorrectly assigned to a user.

.DESCRIPTION
    This reporting function automatically identifies all Autopilot Deployment Profiles 
    configured for 'Shared' (Self-Deploying) usage using a direct Graph API call. 
    It then queries each profile to find exactly which Autopilot devices are assigned 
    to it, bridging the gap to the active Intune managed devices.
    
    Finally, it scans those devices to check if they have an Intune Primary User 
    or an Entra ID Registered Owner attached to them. 

.EXAMPLE
    Get-ITFDeviceInvalidSharedOwner
    Scans the tenant and returns a list of shared devices that have user ownership.
#>
function Get-ITFDeviceInvalidSharedOwner {
    [CmdletBinding()]
    param ()

    try {
        Write-Verbose "Fetching Autopilot Deployment Profiles via Graph API..."
        
        # 1. Identify all profiles that are configured as Self-Deploying / Shared
        $profilesResponse = Invoke-MgGraphRequest -Method GET -Uri "beta/deviceManagement/windowsAutopilotDeploymentProfiles" -ErrorAction Stop
        $sharedProfiles = $profilesResponse.value | Where-Object { $_.outOfBoxExperienceSettings.deviceUsageType -match "shared" }

        if ($null -eq $sharedProfiles -or $sharedProfiles.Count -eq 0) {
            Write-Warning "No Self-Deploying (Shared) Autopilot profiles found in this tenant."
            return
        }

        $profileNames = $sharedProfiles | Select-Object -ExpandProperty displayName
        Write-Host "Found $($sharedProfiles.Count) Shared Autopilot Profile(s): $($profileNames -join ', ')" -ForegroundColor Cyan

        # 2. Get all Autopilot Devices assigned to these specific profiles
        Write-Host "Retrieving assigned hardware devices for these profiles..." -ForegroundColor Cyan
        $sharedAutopilotDevices = @()

        foreach ($autopilotProfile in $sharedProfiles) {
            $uri = "beta/deviceManagement/windowsAutopilotDeploymentProfiles/$($autopilotProfile.id)/assignedDevices"
            
            # Loop to handle pagination (if a profile has more than 1000 devices)
            while ($uri) {
                $response = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
                if ($response.value) {
                    # Add profile name to the object so we can use it later
                    $devicesWithProfile = $response.value | ForEach-Object {
                        $_ | Add-Member -NotePropertyName "DeploymentProfileName" -NotePropertyValue $autopilotProfile.displayName -PassThru
                    }
                    $sharedAutopilotDevices += $devicesWithProfile
                }
                $uri = $response.'@odata.nextLink' # Get the next page URL if it exists
            }
        }

        # Filter out devices that are not yet enrolled in Intune (no managedDeviceId)
        $enrolledAutopilotDevices = $sharedAutopilotDevices | Where-Object { -not [string]::IsNullOrWhiteSpace($_.managedDeviceId) }

        if ($enrolledAutopilotDevices.Count -eq 0) {
            Write-Host "No enrolled devices found that are linked to the shared profiles." -ForegroundColor Green
            return
        }

        # 3. Match them with the actual Intune Managed Devices
        Write-Verbose "Fetching active Intune managed devices..."
        $allIntuneDevices = Get-MgDeviceManagementManagedDevice -All -Property "id,deviceName,serialNumber,userPrincipalName,azureAdDeviceId" -ErrorAction Stop
        
        # Cross-reference the IDs
        $targetManagedDeviceIds = $enrolledAutopilotDevices.managedDeviceId
        $sharedDevices = $allIntuneDevices | Where-Object { $targetManagedDeviceIds -contains $_.Id }

        Write-Host "Scanning $($sharedDevices.Count) active shared device(s) for invalid ownership..." -ForegroundColor Cyan

        $invalidDevices = @()
        $counter = 1

        # 4. Analyze each device for lingering ownership
        foreach ($device in $sharedDevices) {
            
            Write-Progress -Activity "Analyzing Shared Devices" -Status "Checking $($device.DeviceName) ($counter / $($sharedDevices.Count))" -PercentComplete (($counter / $sharedDevices.Count) * 100)
            
            $intuneUser = $device.UserPrincipalName
            $entraOwners = @()
            
            # Look up the correct profile name from our mapping
            $matchedProfileName = ($enrolledAutopilotDevices | Where-Object { $_.managedDeviceId -eq $device.Id }).DeploymentProfileName | Select-Object -First 1

            if (-not [string]::IsNullOrWhiteSpace($device.AzureAdDeviceId)) {
                $entraDevice = Get-MgDevice -Filter "deviceId eq '$($device.AzureAdDeviceId)'" -Property "id" -ErrorAction SilentlyContinue
                
                if ($null -ne $entraDevice) {
                    $owners = Get-MgDeviceRegisteredOwner -DeviceId $entraDevice.Id -ErrorAction SilentlyContinue
                    
                    if ($null -ne $owners -and $owners.Count -gt 0) {
                        foreach ($owner in $owners) {
                            $ownerDetails = Get-MgUser -UserId $owner.Id -Property "userPrincipalName" -ErrorAction SilentlyContinue
                            if ($null -ne $ownerDetails -and -not [string]::IsNullOrWhiteSpace($ownerDetails.UserPrincipalName)) {
                                $entraOwners += $ownerDetails.UserPrincipalName
                            }
                            else {
                                $entraOwners += $owner.Id
                            }
                        }
                    }
                }
            }

            if ((-not [string]::IsNullOrWhiteSpace($intuneUser)) -or ($entraOwners.Count -gt 0)) {
                $invalidDevices += [PSCustomObject]@{
                    DeviceName    = $device.DeviceName
                    SerialNumber  = $device.SerialNumber
                    ProfileName   = $matchedProfileName
                    IntuneOwner   = if ([string]::IsNullOrWhiteSpace($intuneUser)) { "<None>" } else { $intuneUser }
                    EntraIDOwners = if ($entraOwners.Count -eq 0) { "<None>" } else { $entraOwners -join ", " }
                }
            }
            
            $counter++
        }

        Write-Progress -Activity "Analyzing Shared Devices" -Completed

        if ($invalidDevices.Count -eq 0) {
            Write-Host "✅ All shared devices are clean! No invalid users attached." -ForegroundColor Green
        }
        else {
            Write-Warning "Found $($invalidDevices.Count) shared device(s) with invalid user ownership!"
            return $invalidDevices
        }
    }
    catch {
        Write-Error "An error occurred while scanning devices: $($_.Exception.Message)"
    }
}
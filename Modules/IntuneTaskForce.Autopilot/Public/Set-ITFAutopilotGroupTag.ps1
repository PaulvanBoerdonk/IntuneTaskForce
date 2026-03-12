<#
.SYNOPSIS
    Updates the Group Tag for one or multiple Windows Autopilot devices.

.DESCRIPTION
    This function modifies the Group Tag (Order Identifier) of Autopilot devices in Microsoft Intune.
    You can target a single device by its Serial Number, or perform a bulk update by 
    targeting all devices that currently share a specific 'Old' Group Tag.
    
    This function supports -WhatIf so you can safely simulate the changes first.

.PARAMETER NewGroupTag
    The target Group Tag you want to apply to the device(s).

.PARAMETER TargetSerialNumber
    Updates the Group Tag for the specific device matching this hardware Serial Number.

.PARAMETER TargetOldGroupTag
    Updates the Group Tag for ALL devices that currently have this exact Group Tag.
    This is extremely useful for fixing typos in bulk (e.g., tags with accidental spaces).

.EXAMPLE
    Set-ITFAutopilotGroupTag -TargetSerialNumber "PF2A1B3C" -NewGroupTag "Kiosk-PCs"
    Changes the Group Tag of the specific device to 'Kiosk-PCs'.

.EXAMPLE
    Set-ITFAutopilotGroupTag -TargetOldGroupTag "Kiosk " -NewGroupTag "Kiosk-PCs"
    Finds all Autopilot devices that have the typo 'Kiosk ' and updates them to 'Kiosk-PCs'.

.EXAMPLE
    Set-ITFAutopilotGroupTag -TargetOldGroupTag "Kiosk " -NewGroupTag "Kiosk-PCs" -WhatIf
    Simulates the bulk update without actually making changes to Intune.
#>
function Set-ITFAutopilotGroupTag {
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'BySerialNumber')]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string]$NewGroupTag,

        [Parameter(Mandatory = $true, ParameterSetName = 'BySerialNumber')]
        [ValidateNotNullOrEmpty()]
        [string]$TargetSerialNumber,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByOldTag')]
        [AllowEmptyString()]
        [string]$TargetOldGroupTag
    )

    try {
        Write-Verbose "Fetching Autopilot devices to find the target(s)..."
        
        $allDevices = Get-MgDeviceManagementWindowsAutopilotDeviceIdentity -All -PageSize 500 -ErrorAction Stop
        $devicesToUpdate = @()

        # Find the target device(s)
        if ($PSCmdlet.ParameterSetName -eq 'BySerialNumber') {
            $devicesToUpdate = $allDevices | Where-Object { $_.SerialNumber -eq $TargetSerialNumber }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByOldTag') {
            # Filter exactly on the provided string, capturing potential hidden spaces
            $devicesToUpdate = $allDevices | Where-Object { $_.GroupTag -eq $TargetOldGroupTag }
        }

        if ($null -eq $devicesToUpdate -or $devicesToUpdate.Count -eq 0) {
            Write-Warning "No Autopilot devices found matching the specified target criteria."
            return
        }

        Write-Host "Found $($devicesToUpdate.Count) device(s) to update." -ForegroundColor Cyan
        $counter = 1

        foreach ($device in $devicesToUpdate) {
            
            # The built-in PowerShell prompt for ShouldProcess (-WhatIf)
            if ($PSCmdlet.ShouldProcess("Autopilot Device: $($device.SerialNumber)", "Update Group Tag from '$($device.GroupTag)' to '$NewGroupTag'")) {
                
                Write-Host "[$counter/$($devicesToUpdate.Count)] Updating Group Tag for $($device.SerialNumber)..."
                
                try {
                    # Using the correct native Microsoft Graph cmdlet discovered by the user!
                    Update-MgDeviceManagementWindowsAutopilotDeviceIdentityDeviceProperty -WindowsAutopilotDeviceIdentityId $device.Id -GroupTag $NewGroupTag -ErrorAction Stop
                }
                catch {
                    Write-Warning "Failed to update device $($device.SerialNumber). Error: $($_.Exception.Message)"
                }
            }
            $counter++
        }

        Write-Host "Operation completed!" -ForegroundColor Green
    }
    catch {
        if ($_.Exception.Message -match "Authentication needed" -or $_.FullyQualifiedErrorId -match "Authentication") {
            Write-Warning "You are currently not authenticated to Microsoft Graph."
            Write-Host "Please run 'Connect-IntuneTaskForce' to authenticate first." -ForegroundColor Yellow
        }
        else {
            Write-Error "An error occurred during the update process: $($_.Exception.Message)"
        }
    }
}
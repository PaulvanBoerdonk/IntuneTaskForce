<#
.SYNOPSIS
    Triggers a manual rotation of the Windows LAPS local administrator password.

.DESCRIPTION
    This function sends a remote action command via the Microsoft Intune Graph API 
    to force a specific managed device to rotate its LAPS password. 
    It uses a direct Graph Request to the Beta endpoint to avoid SDK module conflicts.
    
    Requires 'DeviceManagementManagedDevices.PrivilegedOperations.All' scope.

.PARAMETER DeviceName
    The display name of the device in Intune.

.EXAMPLE
    Reset-ITFDeviceLapsPassword -DeviceName "WPS-12345"
#>
function Reset-ITFDeviceLapsPassword {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName
    )

    process {
        try {
            Write-Verbose "Searching for Intune managed device '$DeviceName'..."
            
            # 1. Retrieve the Intune Managed Device using stable v1.0 SDK
            $intuneDevice = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$DeviceName'" -Property "id,deviceName" -ErrorAction Stop

            if ($null -eq $intuneDevice) {
                Write-Warning "Device '$DeviceName' not found in Intune."
                return
            }

            # 2. Handle ShouldProcess for -WhatIf support
            if ($PSCmdlet.ShouldProcess($intuneDevice.DeviceName, "Trigger LAPS Local Admin Password Rotation")) {
                
                Write-Host "Triggering LAPS password rotation for $($intuneDevice.DeviceName) via Beta API..." -ForegroundColor Cyan

                # 3. Construct the Beta URI for the specific action
                $uri = "beta/deviceManagement/managedDevices/$($intuneDevice.Id)/rotateLocalAdminPassword"

                # 4. Execute the action via Invoke-MgGraphRequest
                Invoke-MgGraphRequest -Method POST -Uri $uri -ErrorAction Stop

                Write-Host "✅ LAPS password rotation successfully triggered!" -ForegroundColor Green
                Write-Host "The device will rotate its password during the next check-in." -ForegroundColor Gray
            }
        }
        catch {
            $errorMessage = $_.Exception.Message
            if ($errorMessage -match "Authorization_RequestDenied" -or $errorMessage -match "Forbidden") {
                Write-Error "Access Denied. Ensure you have 'DeviceManagementManagedDevices.PrivilegedOperations.All' permissions."
            }
            else {
                Write-Error "Graph API Error: $errorMessage"
            }
        }
    }
}
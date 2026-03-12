<#
.SYNOPSIS
    Retrieves the BitLocker Recovery Key(s) for a specific device.

.DESCRIPTION
    This function queries Entra ID (Azure AD) to retrieve all active BitLocker 
    Recovery Keys associated with a specific device. 
    It requires the 'BitLockerKey.Read.All' Graph API scope.

.PARAMETER DeviceName
    The display name of the device in Entra ID/Intune.

.EXAMPLE
    Get-ITFBitLockerKey -DeviceName "WPS-12345"
    Retrieves the BitLocker recovery key(s) for the specified device.
#>
function Get-ITFBitLockerKey {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName
    )

    try {
        Write-Verbose "Searching for device '$DeviceName' in Entra ID..."
        
        $entraDevice = Get-MgDevice -Filter "displayName eq '$DeviceName'" -ErrorAction Stop

        if ($null -eq $entraDevice) {
            Write-Warning "Device '$DeviceName' not found in Entra ID."
            return
        }
        
        if ($entraDevice.Count -gt 1) {
            Write-Warning "Multiple devices found with the name '$DeviceName'. Please ensure the device name is unique."
            return
        }

        Write-Host "Retrieving BitLocker Recovery Keys for $($entraDevice.DisplayName)..." -ForegroundColor Cyan

        $recoveryKeys = Get-MgInformationProtectionBitlockerRecoveryKey -Filter "deviceId eq '$($entraDevice.DeviceId)'" -ErrorAction Stop

        if ($null -ne $recoveryKeys -and $recoveryKeys.Count -gt 0) {
            foreach ($key in $recoveryKeys) {
                # Fetch the actual key value details
                $keyDetails = Get-MgInformationProtectionBitlockerRecoveryKey -BitlockerRecoveryKeyId $key.Id -Property "key" -ErrorAction Stop
                
                # Convert UTC to Local Timezone
                $localCreatedTime = ([datetime]$key.CreatedDateTime).ToLocalTime()
                
                [PSCustomObject]@{
                    DeviceName      = $entraDevice.DisplayName
                    VolumeType      = $key.VolumeType
                    KeyId           = $key.Id
                    RecoveryKey     = $keyDetails.Key
                    CreatedDateTime = $localCreatedTime
                }
            }
        }
        else {
            Write-Warning "No BitLocker Recovery Keys found for device '$DeviceName' in Entra ID."
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "Authorization_RequestDenied" -or $errorMessage -match "Forbidden") {
            Write-Error "Access Denied. You are missing the 'BitLockerKey.Read.All' scope. Please run Connect-IntuneTaskForce to re-authenticate and consent."
        }
        else {
            Write-Error "Graph API Error: $errorMessage"
        }
    }
}
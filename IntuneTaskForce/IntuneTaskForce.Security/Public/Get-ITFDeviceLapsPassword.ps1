<#
.SYNOPSIS
    Retrieves the active Windows LAPS local administrator password for a specific device.

.DESCRIPTION
    This function queries Entra ID (Azure AD) to retrieve the current Windows LAPS 
    (Local Administrator Password Solution) credential for a given device. 
    It utilizes the native Microsoft Graph SDK cmdlets.
    It requires the 'DeviceLocalCredential.Read.All' Graph API scope.

.PARAMETER DeviceName
    The display name of the device in Entra ID/Intune.

.PARAMETER PasswordAgeDays
    The number of days before the LAPS password expires, based on your Intune policy. 
    Defaults to 7 days. This is used to calculate the ExpirationDateTime.

.EXAMPLE
    Get-ITFDeviceLapsPassword -DeviceName "WPS-12345"
    Retrieves the local admin password and calculates expiration based on a 7-day policy.

.EXAMPLE
    Get-ITFDeviceLapsPassword -DeviceName "WPS-12345" -PasswordAgeDays 14
    Retrieves the local admin password and calculates expiration based on a 14-day policy.
#>
function Get-ITFDeviceLapsPassword {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName,

        [Parameter(Mandatory = $false)]
        [int]$PasswordAgeDays = 7
    )

    try {
        Write-Verbose "Searching for device '$DeviceName' in Entra ID..."
        
        # 1. Retrieve the device (including both Object ID and Azure AD Device ID)
        $entraDevice = Get-MgDevice -Filter "displayName eq '$DeviceName'" -Property "id,deviceId,displayName" -ErrorAction Stop

        if ($null -eq $entraDevice) {
            Write-Warning "Device '$DeviceName' not found in Entra ID."
            return
        }
        
        if ($entraDevice.Count -gt 1) {
            Write-Warning "Multiple devices found with the name '$DeviceName'. Please ensure the device name is unique."
            return
        }

        Write-Host "Retrieving active LAPS password for $($entraDevice.DisplayName)..." -ForegroundColor Cyan

        $lapsInfo = $null
        $foundPassword = $false

        # 2. Try the Object ID first (Microsoft Standard)
        try {
            $lapsInfo = Get-MgDirectoryDeviceLocalCredential -DeviceLocalCredentialInfoId $entraDevice.Id -Property "credentials" -ErrorAction Stop
        }
        catch {
            # Catch the specific Graph error if the Object ID fails
            if ($_.Exception.Message -match "could not be found" -or $_.Exception.Message -match "NotFound") {
                
                # Plan B: Try using the Azure AD Device ID
                try {
                    $lapsInfo = Get-MgDirectoryDeviceLocalCredential -DeviceLocalCredentialInfoId $entraDevice.DeviceId -Property "credentials" -ErrorAction Stop
                }
                catch {
                    if ($_.Exception.Message -match "could not be found" -or $_.Exception.Message -match "NotFound") {
                        Write-Warning "LAPS password record not found in Entra ID for this device."
                        return
                    }
                    throw $_ 
                }
            }
            else {
                throw $_
            }
        }

        # 3. Extract credentials, sort by date, convert timezone, and decode the newest one
        if ($null -ne $lapsInfo -and $null -ne $lapsInfo.Credentials) {
            
            # Collect all valid credentials into an array
            $validCredentials = @()
            foreach ($credential in $lapsInfo.Credentials) {
                if (-not [string]::IsNullOrWhiteSpace($credential.PasswordBase64)) {
                    $validCredentials += $credential
                }
            }

            if ($validCredentials.Count -gt 0) {
                $foundPassword = $true
                
                # Sort the array by BackupDateTime (newest first) and select the top 1
                $activeCredential = $validCredentials | Sort-Object BackupDateTime -Descending | Select-Object -First 1
                
                # Decode Base64 password
                $plainTextPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($activeCredential.PasswordBase64))
                
                # Convert UTC to Local Timezone
                $localBackupTime = ([datetime]$activeCredential.BackupDateTime).ToLocalTime()
                
                # Calculate the Expiration Date using the local time
                $expirationDate = $localBackupTime.AddDays($PasswordAgeDays)
                
                [PSCustomObject]@{
                    DeviceName         = $entraDevice.DisplayName
                    AccountName        = $activeCredential.AccountName
                    Password           = $plainTextPassword
                    BackupDateTime     = $localBackupTime
                    ExpirationDateTime = $expirationDate
                }
            }
        }
        
        if (-not $foundPassword) {
            Write-Warning "No LAPS password found inside the credentials container for '$DeviceName'."
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($errorMessage -match "Authorization_RequestDenied" -or $errorMessage -match "Forbidden" -or $errorMessage -match "Insufficient privileges") {
            Write-Error "Access Denied. You are missing the 'DeviceLocalCredential.Read.All' scope. Please run Connect-IntuneTaskForce to re-authenticate and consent."
        }
        else {
            Write-Error "Graph SDK Error: $errorMessage"
        }
    }
}
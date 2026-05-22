function Show-ITFDeviceDashboard {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$DeviceName
    )

    if ([string]::IsNullOrWhiteSpace($DeviceName)) {
        $DeviceName = Read-Host " > Enter the device name (for example WIN001)"
        if ([string]::IsNullOrWhiteSpace($DeviceName)) { return }
    }

    Write-Host "`n [Info] Fetching data for '$DeviceName'... This may take a few seconds." -ForegroundColor DarkGray

    try {
        $intuneDevice = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$DeviceName'" -ErrorAction Stop

        if (-not $intuneDevice) {
            Write-Warning "Device '$DeviceName' was not found in Intune."
            return
        }

        $lapsData = Get-ITFDeviceLapsPassword -DeviceName $DeviceName -ErrorAction SilentlyContinue
        $bitlockerData = Get-ITFBitLockerKey -DeviceName $DeviceName -ErrorAction SilentlyContinue

        Clear-Host
        Write-Host " ========================================================================" -ForegroundColor Cyan
        Write-Host "                       DEVICE DASHBOARD: $($intuneDevice.DeviceName)     " -ForegroundColor White
        Write-Host " ========================================================================" -ForegroundColor Cyan

        Write-Host "`n * SYSTEM INFORMATION" -ForegroundColor Yellow
        Write-Host "   Manufacturer  : $($intuneDevice.Manufacturer)"
        Write-Host "   Model         : $($intuneDevice.Model)"
        Write-Host "   SerialNumber  : $($intuneDevice.SerialNumber)"
        Write-Host "   OS Version    : $($intuneDevice.OsVersion)"

        Write-Host "`n * INTUNE STATUS" -ForegroundColor Yellow
        Write-Host "   Primary User  : $(if($intuneDevice.UserPrincipalName){$intuneDevice.UserPrincipalName}else{'<None or Shared>'})"
        
        $complianceColor = if ($intuneDevice.ComplianceState -eq 'compliant') { 'Green' } else { 'Red' }
        Write-Host "   Compliance    : " -NoNewline; Write-Host "$($intuneDevice.ComplianceState)" -ForegroundColor $complianceColor
        Write-Host "   Last Sync     : $($intuneDevice.LastSyncDateTime)"

        Write-Host "`n * SECURITY" -ForegroundColor Yellow
        if ($lapsData) {
            Write-Host "   LAPS Password : $($lapsData.Password)" -ForegroundColor Green
            Write-Host "   LAPS Expires  : $($lapsData.ExpirationDateTime)"
        }
        else {
            Write-Host "   LAPS Password : Not found or not configured" -ForegroundColor DarkGray
        }

        if ($bitlockerData) {
            Write-Host "   BitLocker     : $($bitlockerData.Count) Recovery Key(s) found"
            foreach ($key in $bitlockerData) {
                Write-Host "     Key ID        : $($key.KeyId)"
                Write-Host "     Recovery Key  : $($key.RecoveryKey)" -ForegroundColor Green
            }
        }
        else {
            Write-Host "   BitLocker     : No Recovery Keys found" -ForegroundColor DarkGray
        }
        
        Write-Host "`n ========================================================================" -ForegroundColor Cyan
        Write-Host ""
    }
    catch {
        Write-Error "Error fetching dashboard data: $($_.Exception.Message)"
    }
}
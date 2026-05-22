function Get-ITFAutopatchDeviceStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName
    )

    try {
        Write-Host "`n [Info] Fetching Autopatch deployment status for '$DeviceName'..." -ForegroundColor DarkGray
        
        $intuneDevice = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$DeviceName'" -ErrorAction Stop
        if ($null -eq $intuneDevice) {
            Write-Warning "Device '$DeviceName' was not found in Intune."
            return
        }

        $entraDeviceId = $intuneDevice.AzureAdDeviceId
        if ($null -eq $entraDeviceId) {
            Write-Warning "No Entra ID mapping found for this device."
            return
        }

        $entraDevice = Get-MgDevice -Filter "deviceId eq '$entraDeviceId'" -ErrorAction Stop
        $memberOf = Get-MgDeviceMemberOf -DeviceId $entraDevice.Id -ErrorAction Stop
        
        $autopatchGroups = $memberOf | Where-Object { 
            ($_.AdditionalProperties.displayName -match "Autopatch" -or $_.AdditionalProperties.displayName -match "Modern Workplace") -and 
            ($_.AdditionalProperties.displayName -notmatch "Devices All") 
        }

        Clear-Host
        Write-Host " ========================================================================" -ForegroundColor Cyan
        Write-Host "                 AUTOPATCH UPDATE STATUS: $($intuneDevice.DeviceName)    " -ForegroundColor White
        Write-Host " ========================================================================" -ForegroundColor Cyan
        
        Write-Host "`n * DEVICE METRICS" -ForegroundColor Yellow
        Write-Host "   OS Version    : $($intuneDevice.OsVersion)"
        Write-Host "   Patch Level   : $( ($intuneDevice.OsVersion).Split('.')[2] )"
        Write-Host "   Last Sync     : $($intuneDevice.LastSyncDateTime)"

        Write-Host "`n * AUTOPATCH DEPLOYMENT RINGS" -ForegroundColor Yellow
        $assignedRingName = ""

        if ($autopatchGroups.Count -gt 0) {
            foreach ($group in $autopatchGroups) {
                Write-Host "   Assigned Ring : $($group.AdditionalProperties.displayName)" -ForegroundColor Green
                
                if ($group.AdditionalProperties.displayName -match "Test|First|Fast|Broad|Ring\d+") {
                    $assignedRingName = $Matches[0]
                }
            }
        }
        else {
            Write-Host "   Assigned Ring : Not registered in any specific Autopatch deployment ring" -ForegroundColor Red
            Write-Host "   Action Needed : Verify Entra ID group membership" -ForegroundColor DarkGray
        }

        if (-not [string]::IsNullOrEmpty($assignedRingName)) {
            Write-Host "`n * AUTOPATCH POLICY RULES ($assignedRingName)" -ForegroundColor Yellow
            
            $wufbProfiles = Get-MgDeviceManagementDeviceConfiguration -All -ErrorAction SilentlyContinue
            $appliedPolicy = $wufbProfiles | Where-Object { 
                ($_.ODataType -match "windowsUpdateForBusinessConfiguration" -or $_.AdditionalProperties['@odata.type'] -match "windowsUpdateForBusinessConfiguration") -and 
                $_.DisplayName -match $assignedRingName -and 
                ($_.DisplayName -match "Autopatch" -or $_.DisplayName -match "Modern Workplace") 
            } | Select-Object -First 1

            if ($appliedPolicy) {
                Write-Host "   Policy Name          : $($appliedPolicy.DisplayName)"
                Write-Host "   Quality Update Delay : $($appliedPolicy.AdditionalProperties['qualityUpdatesDeferralPeriodInDays']) days"
                Write-Host "   Quality Deadline     : $($appliedPolicy.AdditionalProperties['deadlineForQualityUpdatesInDays']) days"
                Write-Host "   Feature Update Delay : $($appliedPolicy.AdditionalProperties['featureUpdatesDeferralPeriodInDays']) days"
                Write-Host "   Feature Deadline     : $($appliedPolicy.AdditionalProperties['deadlineForFeatureUpdatesInDays']) days"
                Write-Host "   Grace Period         : $($appliedPolicy.AdditionalProperties['deadlineGracePeriodInDays']) days"
            }
            else {
                Write-Host "   Policy Data          : Could not retrieve detailed rules for the $assignedRingName ring." -ForegroundColor DarkGray
            }
        }

        Write-Host "`n ========================================================================" -ForegroundColor Cyan
        Write-Host ""
        
    }
    catch {
        Write-Error "Error fetching Autopatch status: $($_.Exception.Message)"
    }
}
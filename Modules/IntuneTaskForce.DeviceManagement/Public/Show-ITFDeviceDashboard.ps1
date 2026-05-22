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

    Write-Host "`n [Info] Fetching comprehensive data for '$DeviceName'... This may take a few seconds." -ForegroundColor DarkGray

    try {
        # 1. Fetch Intune Device Search
        $deviceSearch = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$DeviceName'" -ErrorAction Stop

        if (-not $deviceSearch) {
            Write-Warning "Device '$DeviceName' was not found in Intune."
            return
        }

        # 2. Fetch Full Device Object (Required for HardwareInformation and Ethernet MAC)
        $intuneDevice = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $deviceSearch.Id -ErrorAction Stop

        # 3. Fetch Security Data (LAPS and BitLocker)
        $lapsData = Get-ITFDeviceLapsPassword -DeviceName $DeviceName -ErrorAction SilentlyContinue
        $bitlockerData = Get-ITFBitLockerKey -DeviceName $DeviceName -ErrorAction SilentlyContinue

        # 4. Fetch Entra ID and Autopatch Data
        $entraDeviceId = $intuneDevice.AzureAdDeviceId
        $assignedRingName = ""
        $fullRingName = ""
        $appliedPolicy = $null
        $accountStatus = "Unknown"

        if ($entraDeviceId) {
            $entraDevice = Get-MgDevice -Filter "deviceId eq '$entraDeviceId'" -Property "id,accountEnabled" -ErrorAction SilentlyContinue
            
            if ($entraDevice) {
                $accountStatus = if ($entraDevice.AccountEnabled) { "Enabled" } else { "Disabled" }
                $memberOf = Get-MgDeviceMemberOf -DeviceId $entraDevice.Id -ErrorAction SilentlyContinue
                
                $autopatchGroups = $memberOf | Where-Object { 
                    ($_.AdditionalProperties.displayName -match "Autopatch" -or $_.AdditionalProperties.displayName -match "Modern Workplace") -and 
                    ($_.AdditionalProperties.displayName -notmatch "Devices All") 
                }
                
                if ($autopatchGroups.Count -gt 0) {
                    foreach ($group in $autopatchGroups) {
                        if ($group.AdditionalProperties.displayName -match "Test|First|Fast|Broad|Ring\d+") {
                            $assignedRingName = $Matches[0]
                            $fullRingName = $group.AdditionalProperties.displayName
                            break
                        }
                    }
                }
                
                if (-not [string]::IsNullOrEmpty($assignedRingName)) {
                    $wufbProfiles = Get-MgDeviceManagementDeviceConfiguration -All -ErrorAction SilentlyContinue
                    $appliedPolicy = $wufbProfiles | Where-Object { 
                        ($_.ODataType -match "windowsUpdateForBusinessConfiguration" -or $_.AdditionalProperties['@odata.type'] -match "windowsUpdateForBusinessConfiguration") -and 
                        $_.DisplayName -match $assignedRingName -and 
                        ($_.DisplayName -match "Autopatch" -or $_.DisplayName -match "Modern Workplace") 
                    } | Select-Object -First 1
                }
            }
        }

        # 5. Fetch Autopilot Data
        $autopilotDevice = $null
        if ($intuneDevice.SerialNumber) {
            $autopilotDevice = Get-MgDeviceManagementWindowsAutopilotDeviceIdentity -All -ErrorAction SilentlyContinue | Where-Object { $_.SerialNumber -eq $intuneDevice.SerialNumber } | Select-Object -First 1
        }
        $groupTag = if ($autopilotDevice -and -not [string]::IsNullOrEmpty($autopilotDevice.GroupTag)) { $autopilotDevice.GroupTag } else { "<None or Not Autopilot>" }

        # Extract Hardware Information reliably
        $ethMacAddress = if ($intuneDevice.EthernetMacAddress) { $intuneDevice.EthernetMacAddress } else { '<Not reported>' }
        $wifiMacAddress = if ($intuneDevice.WiFiMacAddress) { $intuneDevice.WiFiMacAddress } else { '<Not reported>' }

        # 6. Render Dashboard Output
        Clear-Host
        Write-Host " ========================================================================" -ForegroundColor Cyan
        Write-Host "                       DEVICE DASHBOARD: $($intuneDevice.DeviceName)     " -ForegroundColor White
        Write-Host " ========================================================================" -ForegroundColor Cyan

        Write-Host "`n * SYSTEM and NETWORK" -ForegroundColor Yellow
        Write-Host "   Manufacturer  : $($intuneDevice.Manufacturer)"
        Write-Host "   Model         : $($intuneDevice.Model)"
        Write-Host "   SerialNumber  : $($intuneDevice.SerialNumber)"
        Write-Host "   OS Version    : $($intuneDevice.OsVersion)"
        Write-Host "   Ethernet MAC  : $ethMacAddress"
        Write-Host "   Wi-Fi MAC     : $wifiMacAddress"

        Write-Host "`n * IDENTITY and INTUNE" -ForegroundColor Yellow
        Write-Host "   Primary User  : $(if($intuneDevice.UserPrincipalName){$intuneDevice.UserPrincipalName}else{'<None or Shared>'})"
        
        $accountColor = if ($accountStatus -eq 'Enabled') { 'Green' } else { 'Red' }
        Write-Host "   Entra Account : " -NoNewline; Write-Host $accountStatus -ForegroundColor $accountColor
        
        $complianceColor = if ($intuneDevice.ComplianceState -eq 'compliant') { 'Green' } else { 'Red' }
        Write-Host "   Compliance    : " -NoNewline; Write-Host "$($intuneDevice.ComplianceState)" -ForegroundColor $complianceColor
        Write-Host "   Last Sync     : $($intuneDevice.LastSyncDateTime)"

        Write-Host "`n * AUTOPILOT and UPDATES" -ForegroundColor Yellow
        Write-Host "   Group Tag     : $groupTag"
        Write-Host "   Patch Level   : $( ($intuneDevice.OsVersion).Split('.')[2] )"
        
        if ($assignedRingName) {
            Write-Host "   Assigned Ring : $fullRingName" -ForegroundColor Green
            if ($appliedPolicy) {
                Write-Host "   Quality Delay : $($appliedPolicy.AdditionalProperties['qualityUpdatesDeferralPeriodInDays']) days (Deadline: $($appliedPolicy.AdditionalProperties['deadlineForQualityUpdatesInDays']) days)"
                Write-Host "   Feature Delay : $($appliedPolicy.AdditionalProperties['featureUpdatesDeferralPeriodInDays']) days (Deadline: $($appliedPolicy.AdditionalProperties['deadlineForFeatureUpdatesInDays']) days)"
            }
            else {
                Write-Host "   Policy Data   : Detailed rules not found for $assignedRingName" -ForegroundColor DarkGray
            }
        }
        else {
            Write-Host "   Assigned Ring : Not registered in any specific Autopatch ring" -ForegroundColor Red
        }

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
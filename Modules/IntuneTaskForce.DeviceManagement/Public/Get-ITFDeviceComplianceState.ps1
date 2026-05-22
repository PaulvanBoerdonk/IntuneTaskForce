function Get-ITFDeviceComplianceState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName
    )

    try {
        Write-Verbose "Searching for device '$DeviceName' in Intune..."
        
        $intuneDevice = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$DeviceName'" -Property "id,deviceName,complianceState" -ErrorAction Stop

        if ($null -eq $intuneDevice) {
            Write-Warning "Device '$DeviceName' not found in Intune."
            return
        }

        Write-Host "Analyzing compliance state for $($intuneDevice.DeviceName)..." -ForegroundColor Cyan
        
        $statusColor = if ($intuneDevice.ComplianceState -eq 'compliant') { 'Green' } else { 'Red' }
        Write-Host "Overall Status: $($intuneDevice.ComplianceState)" -ForegroundColor $statusColor

        if ($intuneDevice.ComplianceState -eq 'compliant') {
            Write-Host "The device meets all compliance requirements." -ForegroundColor Green
            return
        }

        $policyStates = Get-MgDeviceManagementManagedDeviceCompliancePolicyState -ManagedDeviceId $intuneDevice.Id -ErrorAction Stop
        
        $nonCompliantPolicies = $policyStates | Where-Object { $_.State -ne 'compliant' -and $_.State -ne 'notApplicable' }

        if ($nonCompliantPolicies.Count -gt 0) {
            Write-Host "`nFailing Compliance Policies:" -ForegroundColor Yellow
            foreach ($policy in $nonCompliantPolicies) {
                [PSCustomObject]@{
                    PolicyName = $policy.DisplayName
                    State      = $policy.State
                    Platform   = $policy.PlatformType
                }
            }
        }
        else {
            Write-Host "`nNo specific failing policies found. The device might be in a grace period." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Error "An error occurred while fetching compliance state: $($_.Exception.Message)"
    }
}
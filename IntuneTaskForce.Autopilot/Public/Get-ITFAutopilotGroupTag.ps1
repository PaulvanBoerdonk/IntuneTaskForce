<#
.SYNOPSIS
    Retrieves Windows Autopilot device identities and their associated Group Tags.

.DESCRIPTION
    This function queries Microsoft Intune for Windows Autopilot devices. 
    It can return all devices, filter by a specific Group Tag or Serial Number,
    or list all unique Group Tags currently in use across the tenant.

.PARAMETER GroupTag
    Filter the results to only show devices with this specific Group Tag.

.PARAMETER SerialNumber
    Filter the results to find a specific device by its hardware Serial Number.

.PARAMETER Unique
    Returns a list of all unique Group Tags currently in use, along with the 
    number of devices assigned to each tag.

.PARAMETER IncludeDevices
    Can only be used together with -Unique. It expands the output to include a nested 
    list of the specific devices (SerialNumber) that have that Group Tag.

.EXAMPLE
    Get-ITFAutopilotGroupTag -Unique
    Retrieves a list of all unique Group Tags and the count of devices per tag.

.EXAMPLE
    Get-ITFAutopilotGroupTag -Unique -IncludeDevices
    Retrieves the unique Group Tags, including a nested list of devices for each tag.
#>
function Get-ITFAutopilotGroupTag {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(ParameterSetName = 'Default')]
        [string]$GroupTag,

        [Parameter(ParameterSetName = 'Default')]
        [string]$SerialNumber,

        [Parameter(Mandatory = $true, ParameterSetName = 'Unique')]
        [switch]$Unique,

        [Parameter(ParameterSetName = 'Unique')]
        [switch]$IncludeDevices
    )

    try {
        Write-Verbose "Fetching Autopilot devices from Microsoft Graph..."
        
        $allDevices = Get-MgDeviceManagementWindowsAutopilotDeviceIdentity -All -PageSize 500 -ErrorAction Stop

        if ($null -eq $allDevices -or $allDevices.Count -eq 0) {
            Write-Warning "No Autopilot devices found in this tenant."
            return
        }

        # Handle the -Unique switch
        if ($Unique) {
            Write-Verbose "Grouping devices to find unique Group Tags..."
            
            # Dynamically build the properties we want to return
            $selectProperties = @(
                @{Name = 'GroupTag'; Expression = { 
                        if ([string]::IsNullOrEmpty($_.Name)) { 
                            "<Empty/No Tag>" 
                        }
                        else { 
                            "'$($_.Name)'" 
                        } 
                    }
                },
                @{Name = 'DeviceCount'; Expression = { $_.Count } }
            )

            # If the user wants to see the specific devices, add the nested objects
            if ($IncludeDevices) {
                $selectProperties += @{Name = 'Devices'; Expression = {
                        $_.Group | Select-Object `
                        @{Name = 'SerialNumber'; Expression = { $_.SerialNumber } },
                        @{Name = 'Id'; Expression = { $_.Id } }
                    }
                }
            }
            
            $uniqueTags = $allDevices | Group-Object GroupTag | Select-Object $selectProperties | Sort-Object DeviceCount -Descending

            return $uniqueTags
        }

        # Handle standard filtering
        $devices = @()

        if ($PSBoundParameters.ContainsKey('SerialNumber')) {
            $devices = $allDevices | Where-Object { $_.SerialNumber -eq $SerialNumber }
        }
        elseif ($PSBoundParameters.ContainsKey('GroupTag')) {
            $devices = $allDevices | Where-Object { $_.GroupTag -eq $GroupTag }
        }
        else {
            $devices = $allDevices
        }

        if ($null -eq $devices -or $devices.Count -eq 0) {
            Write-Warning "No Autopilot devices found matching the specified criteria."
            return
        }

        # Format the standard output
        $devices | Select-Object `
        @{Name = 'SerialNumber'; Expression = { $_.SerialNumber } },
        @{Name = 'GroupTag'; Expression = {
                if ([string]::IsNullOrEmpty($_.GroupTag)) { 
                    "<Empty/No Tag>" 
                }
                else { 
                    "'$($_.GroupTag)'" 
                }
            }
        },
        @{Name = 'EnrollmentState'; Expression = { $_.EnrollmentState } },
        @{Name = 'Id'; Expression = { $_.Id } }
    }
    catch {
        if ($_.Exception.Message -match "Authentication needed" -or $_.FullyQualifiedErrorId -match "Authentication") {
            Write-Warning "You are currently not authenticated to Microsoft Graph."
            Write-Host "Please run 'Connect-IntuneTaskForce' to authenticate first." -ForegroundColor Yellow
        }
        else {
            Write-Error "An error occurred while retrieving Autopilot devices: $($_.Exception.Message)"
        }
    }
}
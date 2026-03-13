<#
.SYNOPSIS
    Interactive console menu for the IntuneTaskForce module.

.DESCRIPTION
    This function provides a user-friendly, text-based interface for service desk 
    agents and administrators to execute IntuneTaskForce commands without needing 
    to memorize PowerShell cmdlets and parameters.

.NOTES
    Author: Paul van Boerdonk
#>
function Start-IntuneTaskForce {
    [CmdletBinding()]
    param ()

    # Helper function to clear the screen and show the main logo
    function Show-Header {
        Clear-Host
        Write-Host ""
        Write-Host "  _____      _                  _____         _   ______                 " -ForegroundColor Blue
        Write-Host " |_   _|    | |                |_   _|       | |  |  ___|                " -ForegroundColor Blue
        Write-Host "   | | _ __ | |_ _   _ _ __   ___| | __ _ ___| | _| |_ ___  _ __ ___ ___ " -ForegroundColor Cyan
        Write-Host "   | || '_ \| __| | | | '_ \ / _ \ |/ _  / __| |/ /  _/ _ \| '__/ __/ _ \" -ForegroundColor Cyan
        Write-Host "  _| || | | | |_| |_| | | | |  __/ | (_| \__ \   <| || (_) | | | (_|  __/" -ForegroundColor Cyan
        Write-Host "  \___/_| |_|\__|\__,_|_| |_|\___\_/\__,_|___/_|\_\_| \___/|_|  \___\___|" -ForegroundColor Cyan
        Write-Host " ========================================================================" -ForegroundColor DarkGray
        Write-Host "                 INTUNE TASK FORCE - ADMIN CONSOLE v1.0                  " -ForegroundColor DarkGray
        Write-Host " ========================================================================" -ForegroundColor DarkGray
        Write-Host ""
    }

    # Helper function to pause the screen
    function Show-Pause {
        Write-Host "`n[!] Press any key to return to the main menu..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }

    # Helper function to print stylish menu items without the weird spacing
    function Write-MenuItem {
        param (
            [string]$Key,
            [string]$Text
        )
        # Add dynamic padding AFTER the bracket to align the text properly
        $spacing = if ($Key.Length -eq 1) { "  " } else { " " }
        
        Write-Host "   [" -NoNewline -ForegroundColor DarkGray
        Write-Host $Key -NoNewline -ForegroundColor Green
        Write-Host "]$spacing" -NoNewline -ForegroundColor DarkGray
        Write-Host $Text -ForegroundColor White
    }

    # Helper function to print category headers
    function Write-CategoryHeader {
        param ([string]$Title)
        Write-Host " ❖ $Title" -ForegroundColor Cyan
    }

    # Helper function to ask for Simulation Mode (-WhatIf)
    function Confirm-Simulation {
        Write-Host "`n Would you like to simulate this action first to see what happens?" -ForegroundColor Yellow
        $simulate = Read-Host " ❯ Run in Simulation Mode (-WhatIf)? (Y/N)"
        Write-Host ""
        return ($simulate -match "^[Yy]")
    }

    $menuLoop = $true

    while ($menuLoop) {
        Show-Header
        
        Write-CategoryHeader "Authentication"
        Write-MenuItem "1" "Connect to Microsoft Graph"
        Write-MenuItem "2" "Disconnect from Microsoft Graph"
        Write-Host ""
        
        Write-CategoryHeader "Device Management & Actions"
        Write-MenuItem "3" "Sync Devices in Bulk"
        Write-MenuItem "4" "Clear Device Owner (Intune & Entra ID)"
        Write-MenuItem "5" "Find Invalid Shared Device Owners"
        Write-Host ""
        
        Write-CategoryHeader "Security (LAPS & BitLocker)"
        Write-MenuItem "6" "Get BitLocker Recovery Key"
        Write-MenuItem "7" "Get Device LAPS Password"
        Write-MenuItem "8" "Trigger LAPS Password Reset"
        Write-Host ""
        
        Write-CategoryHeader "Autopilot Management"
        Write-MenuItem "9" "Show Unique Autopilot Group Tags"
        Write-MenuItem "10" "Update Autopilot Group Tag (By Serial)"
        Write-MenuItem "11" "Replace Autopilot Group Tag (Bulk)"
        
        Write-Host "`n -------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-MenuItem "Q" "Quit Application"
        Write-Host " -------------------------------------------------------------------`n" -ForegroundColor DarkGray

        Write-Host " ❯ " -NoNewline -ForegroundColor Green
        $selection = Read-Host "Select an option"

        switch ($selection) {
            '1' { 
                Show-Header
                Write-Host " ❖ Connect to Microsoft Graph" -ForegroundColor Cyan
                Write-Host " Authenticates your session with all required permissions.`n" -ForegroundColor DarkGray
                Connect-IntuneTaskForce
                Show-Pause 
            }
            '2' { 
                Show-Header
                Write-Host " ❖ Disconnect from Microsoft Graph" -ForegroundColor Cyan
                Write-Host " Safely closes your active Graph session.`n" -ForegroundColor DarkGray
                Disconnect-IntuneTaskForce
                Show-Pause 
            }
            '3' {
                Show-Header
                Write-Host " ❖ Sync Devices in Bulk" -ForegroundColor Cyan
                Write-Host " Triggers a lightning-fast bulk sync action in Intune, bypassing the GUI limit.`n" -ForegroundColor DarkGray
                Write-MenuItem "A" "Sync by Device Name Prefix"
                Write-MenuItem "B" "Sync by Entra ID Group Name"
                Write-MenuItem "Q" "Cancel and return to Main Menu"
                Write-Host "`n ❯ " -NoNewline -ForegroundColor Green
                $syncChoice = Read-Host "Select A, B, or Q"

                if ($syncChoice -in 'Q', 'q') { continue }

                Write-Host ""
                if ($syncChoice -eq 'A' -or $syncChoice -eq 'a') {
                    $prefix = Read-Host " ❯ Enter Device Name Prefix (e.g., WIN-)"
                    if (-not [string]::IsNullOrWhiteSpace($prefix)) { Sync-ITFBulkDevice -DeviceNamePrefix $prefix }
                }
                elseif ($syncChoice -eq 'B' -or $syncChoice -eq 'b') {
                    $groupName = Read-Host " ❯ Enter Entra ID Group Name"
                    if (-not [string]::IsNullOrWhiteSpace($groupName)) { Sync-ITFBulkDevice -GroupName $groupName }
                }
                Show-Pause
            }
            '4' {
                Show-Header
                Write-Host " ❖ Clear Device Owner (Intune & Entra ID)" -ForegroundColor Cyan
                Write-Host " Removes the Primary User in Intune AND the Registered Owner from Entra ID.`n" -ForegroundColor DarkGray
                $deviceName = Read-Host " ❯ Enter Intune Device Name to clear (or 'Q' to cancel)"
                
                if ($deviceName -in 'Q', 'q') { continue }
                
                if (-not [string]::IsNullOrWhiteSpace($deviceName)) { 
                    $isSim = Confirm-Simulation
                    if ($isSim) {
                        Write-Host " Running in Simulation Mode..." -ForegroundColor Cyan
                        Clear-ITFDeviceOwner -DeviceName $deviceName -WhatIf
                    }
                    else {
                        Write-Host " Applying changes..." -ForegroundColor Cyan
                        Clear-ITFDeviceOwner -DeviceName $deviceName
                    }
                }
                Show-Pause
            }
            '5' {
                Show-Header
                Write-Host " ❖ Find Invalid Shared Device Owners" -ForegroundColor Cyan
                Write-Host " Scans shared Autopilot devices to identify lingering user ownership.`n" -ForegroundColor DarkGray
                Get-ITFDeviceInvalidSharedOwner | Format-Table -AutoSize
                Show-Pause
            }
            '6' {
                Show-Header
                Write-Host " ❖ Get BitLocker Recovery Key" -ForegroundColor Cyan
                Write-Host " Retrieves active BitLocker Recovery Keys for a specific device.`n" -ForegroundColor DarkGray
                $deviceName = Read-Host " ❯ Enter Device Name (or 'Q' to cancel)"
                
                if ($deviceName -in 'Q', 'q') { continue }
                
                Write-Host ""
                if (-not [string]::IsNullOrWhiteSpace($deviceName)) { Get-ITFBitLockerKey -DeviceName $deviceName | Format-List }
                Show-Pause
            }
            '7' {
                Show-Header
                Write-Host " ❖ Get Device LAPS Password" -ForegroundColor Cyan
                Write-Host " Retrieves the current Windows LAPS credential and calculates the expiration date.`n" -ForegroundColor DarkGray
                $deviceName = Read-Host " ❯ Enter Device Name (or 'Q' to cancel)"
                
                if ($deviceName -in 'Q', 'q') { continue }
                
                Write-Host ""
                if (-not [string]::IsNullOrWhiteSpace($deviceName)) { Get-ITFDeviceLapsPassword -DeviceName $deviceName | Format-List }
                Show-Pause
            }
            '8' {
                Show-Header
                Write-Host " ❖ Trigger LAPS Password Reset" -ForegroundColor Cyan
                Write-Host " Forces the device to rotate its local admin password at the next check-in.`n" -ForegroundColor DarkGray
                $deviceName = Read-Host " ❯ Enter Device Name (or 'Q' to cancel)"
                
                if ($deviceName -in 'Q', 'q') { continue }
                
                if (-not [string]::IsNullOrWhiteSpace($deviceName)) { 
                    $isSim = Confirm-Simulation
                    if ($isSim) {
                        Write-Host " Running in Simulation Mode..." -ForegroundColor Cyan
                        Reset-ITFDeviceLapsPassword -DeviceName $deviceName -WhatIf
                    }
                    else {
                        Write-Host " Applying changes..." -ForegroundColor Cyan
                        Reset-ITFDeviceLapsPassword -DeviceName $deviceName
                    }
                }
                Show-Pause
            }
            '9' {
                Show-Header
                Write-Host " ❖ Show Unique Autopilot Group Tags" -ForegroundColor Cyan
                Write-Host " Retrieves a list of all unique Group Tags and the device count per tag.`n" -ForegroundColor DarkGray
                Write-Host " Fetching Autopilot Group Tags..." -ForegroundColor Cyan
                Get-ITFAutopilotGroupTag -Unique | Format-Table -AutoSize
                Show-Pause
            }
            '10' {
                Show-Header
                Write-Host " ❖ Update Autopilot Group Tag (By Serial)" -ForegroundColor Cyan
                Write-Host " Modifies the Group Tag for a specific Autopilot device.`n" -ForegroundColor DarkGray
                $serial = Read-Host " ❯ Enter Hardware Serial Number (or 'Q' to cancel)"
                
                if ($serial -in 'Q', 'q') { continue }
                
                $newTag = Read-Host " ❯ Enter the NEW Group Tag"
                
                if (-not [string]::IsNullOrWhiteSpace($serial) -and $null -ne $newTag) {
                    $isSim = Confirm-Simulation
                    if ($isSim) {
                        Write-Host " Running in Simulation Mode..." -ForegroundColor Cyan
                        Set-ITFAutopilotGroupTag -TargetSerialNumber $serial -NewGroupTag $newTag -WhatIf
                    }
                    else {
                        Write-Host " Applying changes..." -ForegroundColor Cyan
                        Set-ITFAutopilotGroupTag -TargetSerialNumber $serial -NewGroupTag $newTag
                    }
                }
                Show-Pause
            }
            '11' {
                Show-Header
                Write-Host " ❖ Replace Autopilot Group Tag (Bulk)" -ForegroundColor Cyan
                Write-Host " Finds all devices with a specific old Group Tag and updates them to a new one.`n" -ForegroundColor DarkGray
                
                $oldTag = Read-Host " ❯ Enter the OLD Group Tag to replace (or 'Q' to cancel)"
                if ($oldTag -in 'Q', 'q') { continue }
                
                $newTag = Read-Host " ❯ Enter the NEW Group Tag"
                
                if (-not [string]::IsNullOrWhiteSpace($oldTag)) {
                    $isSim = Confirm-Simulation
                    if ($isSim) {
                        Write-Host " Running in Simulation Mode..." -ForegroundColor Cyan
                        Set-ITFAutopilotGroupTag -TargetOldGroupTag $oldTag -NewGroupTag $newTag -WhatIf
                    }
                    else {
                        Write-Host " Applying changes..." -ForegroundColor Cyan
                        Set-ITFAutopilotGroupTag -TargetOldGroupTag $oldTag -NewGroupTag $newTag
                    }
                }
                Show-Pause
            }
            { $_ -in 'Q', 'q' } {
                Show-Header
                Write-Host " Exiting IntuneTaskForce Console. Goodbye!`n" -ForegroundColor Green
                $menuLoop = $false
            }
            Default {
                Write-Warning "Invalid selection. Please try again."
                Start-Sleep -Seconds 2
            }
        }
    }
}
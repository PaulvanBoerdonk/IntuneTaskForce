# IntuneTaskForce

The **IntuneTaskForce** module is a powerful Enterprise PowerShell toolkit specifically built to automate and accelerate the management of Microsoft Intune, Windows Autopilot, and Entra ID. This module combines various complex Graph API calls into simple, intuitive commands.

## Installation

The module is available via the PowerShell Gallery and is installed as a complete 'Umbrella Module'.

```powershell
# Install the module for the current user
Install-Module -Name IntuneTaskForce -Scope CurrentUser -Force

# Import the module into your session
Import-Module IntuneTaskForce
```

---

## Interactive Console (TUI)

If you want to use the module without typing commands manually (ideal for Service Desk or Helpdesk teams), the umbrella module includes a built-in Text User Interface (TUI).

### `Start-ITFConsole`

Launches an interactive, menu-driven console that allows you to execute all major actions within this module securely and easily. Simply select the action you want to perform and follow the on-screen prompts.

```powershell
Start-ITFConsole
```

---

## 1. Authentication (Session Management)

These commands are used to securely log in to the Microsoft Graph API. The module automatically handles the necessary Graph permissions (scopes) in the background.

### `Connect-IntuneTaskForce`

Connects to Microsoft Graph with all the required scopes for the actions within this module. It automatically checks if your session is active and if you possess the necessary permissions.

```powershell
Connect-IntuneTaskForce
```

### `Disconnect-IntuneTaskForce`

Safely and cleanly closes your active Microsoft Graph session.

```powershell
Disconnect-IntuneTaskForce
```

---

## 2. Autopilot Management

These commands focus on the hardware records within Windows Autopilot.

### `Get-ITFAutopilotGroupTag`

Retrieves Windows Autopilot devices and their associated Group Tags from the tenant. Perfect for reporting or tracking down incorrect tags.

```powershell
# Show all unique Group Tags and the device count per tag
Get-ITFAutopilotGroupTag -Unique

# Show all unique Group Tags, including the underlying devices
Get-ITFAutopilotGroupTag -Unique -IncludeDevices
```

### `Set-ITFAutopilotGroupTag`

Modifies the Group Tag for one or multiple Autopilot devices. Ideal for fixing typos (like accidental spaces) in bulk. Supports `-WhatIf` to safely simulate actions.

```powershell
# Update the tag for one specific device
Set-ITFAutopilotGroupTag -TargetSerialNumber "PF2A1B3C" -NewGroupTag "Kiosk-PCs"

# Bulk action: Find all devices with a space typo and fix them
Set-ITFAutopilotGroupTag -TargetOldGroupTag "Kiosk " -NewGroupTag "Kiosk-PCs" -WhatIf
```

---

## 3. Device Management

Built for operational management and cleaning up active devices in Intune and Entra ID.

### `Clear-ITFDeviceOwner`

When an Intune device is wiped and repurposed as a Shared Device (Self-Deploying), the original user often remains attached as the Registered Owner in Entra ID. This command removes the _Primary User_ in Intune AND completely strips the _Registered Owner_ from Entra ID.

```powershell
Clear-ITFDeviceOwner -DeviceName "WPS-12345" -WhatIf
```

### `Get-ITFDeviceInvalidSharedOwner`

A smart reporting function. It automatically finds all Autopilot Deployment Profiles configured for 'Shared' (Self-Deploying) usage. It then scans all active devices under these profiles and identifies which ones incorrectly still have a Primary User or Entra ID Registered Owner attached.

```powershell
Get-ITFDeviceInvalidSharedOwner | Format-Table -AutoSize
```

---

## 4. Bulk Actions

For managing large groups of devices in Intune simultaneously, bypassing standard GUI limits.

### `Sync-ITFBulkDevice`

Retrieves devices and triggers a lightning-fast bulk sync action in Intune.

```powershell
# Sync based on a device name prefix
Sync-ITFBulkDevice -DeviceNamePrefix "WIN-"

# Sync all devices within a specific Entra ID group
Sync-ITFBulkDevice -GroupName "Workstations-Device-Group"
```

---

## 5. Security (LAPS & BitLocker)

These commands manage device security features, including Windows LAPS local administrator passwords and BitLocker recovery keys.

### `Get-ITFBitLockerKey`

Queries Entra ID to retrieve all active BitLocker Recovery Keys associated with a specific device.

```powershell
Get-ITFBitLockerKey -DeviceName "WPS-12345"
```

### `Get-ITFDeviceLapsPassword`

Retrieves the current Windows LAPS (Local Administrator Password Solution) credential for a given device from Entra ID. It also calculates the expiration date based on your Intune policy.

```powershell
# Get the active password (defaults to a 7-day expiration policy calculation)
Get-ITFDeviceLapsPassword -DeviceName "WPS-12345"

# Get the password and calculate expiration based on a 14-day policy
Get-ITFDeviceLapsPassword -DeviceName "WPS-12345" -PasswordAgeDays 14
```

### `Reset-ITFDeviceLapsPassword`

Sends a remote action command via the Microsoft Intune Graph API to force a specific managed device to rotate its LAPS password. The device will rotate its password during the next check-in.

```powershell
Reset-ITFDeviceLapsPassword -DeviceName "WPS-12345"
```

---

_Created by Paul van Boerdonk. Feedback, ideas, and pull requests are always welcome!_

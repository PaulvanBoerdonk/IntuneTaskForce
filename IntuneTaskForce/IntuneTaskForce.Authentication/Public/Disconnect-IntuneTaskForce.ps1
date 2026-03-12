<#
.SYNOPSIS
    Disconnects the current Microsoft Graph session.

.DESCRIPTION
    This function acts as a wrapper around Disconnect-MgGraph to safely close 
    the active session for IntuneTaskForce without the noisy Microsoft output.
#>
function Disconnect-IntuneTaskForce {
    [CmdletBinding()]
    param ()

    try {
        # Check if actually connected first
        $currentContext = Get-MgContext -ErrorAction SilentlyContinue
        
        if ($null -eq $currentContext) {
            Write-Host "You are not currently connected to Microsoft Graph." -ForegroundColor Yellow
            return
        }

        Write-Host "Disconnecting from Microsoft Graph..." -ForegroundColor Cyan
        
        # Disconnect and suppress the returned context object
        $null = Disconnect-MgGraph -ErrorAction SilentlyContinue
        
        Write-Host "Successfully disconnected." -ForegroundColor Green
    }
    catch {
        Write-Error "An error occurred while disconnecting: $_"
    }
}
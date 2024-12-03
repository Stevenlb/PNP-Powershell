# Import PnP PowerShell module
Import-Module PnP.PowerShell

# Parameters
param(
    [Parameter(Mandatory=$true)]
    [string]$SiteUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputPath,
    
    [Parameter(Mandatory=$false)]
    [System.Management.Automation.PSCredential]$Credentials,

    [Parameter(Mandatory=$false)]
    [switch]$Append
)

try {
    # Connect to SharePoint site
    if ($Credentials) {
        Connect-PnPOnline -Url $SiteUrl -Credentials $Credentials
    } else {
        Connect-PnPOnline -Url $SiteUrl -Interactive
    }

    Write-Host "Connected to SharePoint site: $SiteUrl" -ForegroundColor Green

    # Get all lists and libraries
    $lists = Get-PnPList

    # Create array to store results
    $results = @()

    foreach ($list in $lists) {
        # Skip hidden lists and system lists
        if (-not $list.Hidden) {
            $listUrl = $list.DefaultViewUrl
            $settingsUrl = "$SiteUrl/_layouts/15/listedit.aspx?List={$($list.Id)}"

            $resultObject = [PSCustomObject]@{
                SiteUrl = $SiteUrl
                Title = $list.Title
                BaseTemplate = $list.BaseTemplate
                ItemCount = $list.ItemCount
                LastModified = $list.LastItemModifiedDate
                ListUrl = $listUrl
                SettingsUrl = $settingsUrl
                IsDocumentLibrary = $list.BaseTemplate -eq 101
                EnableVersioning = $list.EnableVersioning
                MajorVersionLimit = $list.MajorVersionLimit
                Hidden = $list.Hidden
                ExportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }

            $results += $resultObject
        }
    }

    # Check if file exists and Append switch is used
    if ($Append -and (Test-Path $OutputPath)) {
        $results | Export-Csv -Path $OutputPath -NoTypeInformation -Append
        Write-Host "Appended results to existing report at: $OutputPath" -ForegroundColor Green
    } else {
        $results | Export-Csv -Path $OutputPath -NoTypeInformation
        Write-Host "Created new report at: $OutputPath" -ForegroundColor Green
    }

    Write-Host "Lists and libraries processed in this run: $($results.Count)" -ForegroundColor Green

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    # Disconnect from SharePoint
    Disconnect-PnPOnline
}

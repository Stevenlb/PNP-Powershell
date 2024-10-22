function Update-ListView {
    param (
        [Parameter(Mandatory=$true)]
        [string]$SiteUrl,

        [Parameter(Mandatory=$true)]
        [string]$ListName,

        [Parameter(Mandatory=$false)]
        [string]$ViewName = "Client status"
    )

    try {
        # Connect to the SharePoint site
        Connect-PnPOnline -Url $SiteUrl -Interactive

        # Get the list
        $list = Get-PnPList -Identity $ListName
        if (-not $list) {
            Write-Error "List '$ListName' not found."
            return
        }

        # Get the view
        $view = Get-PnPView -List $list -Identity $ViewName
        if (-not $view) {
            Write-Error "View '$ViewName' not found in the list '$ListName'."
            return
        }

        # Prepare the CAML query for filtering
        $camlQuery = "<Where><Or><Eq><FieldRef Name='Status'/><Value Type='Choice'>In Progress</Value></Eq><Eq><FieldRef Name='Status'/><Value Type='Choice'>Not Started</Value></Eq></Or></Where>"

        # Update the view
        Set-PnPView -List $list -Identity $view -Fields "Title", "Status", "DueDate" -ViewQuery $camlQuery -OrderBy @{"DueDate" = $false} -Paged $true -RowLimit 30

        Write-Host "View '$ViewName' in list '$ListName' has been successfully updated." -ForegroundColor Green
    }
    catch {
        Write-Error "An error occurred: $_"
    }
    finally {
        # Disconnect from SharePoint
        Disconnect-PnPOnline
    }
}

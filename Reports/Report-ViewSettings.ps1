function Export-SharePointViewsToCSV {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SiteUrl
    )

    # Set Report file
    $CsvPath = "C:\Reports\ViewSettings.csv"

    # Connect to the SharePoint site
    Connect-PnPOnline -Url $SiteUrl -ClientId xxxxxxxx-xxxx-xxxxxxxx-xxxx-xxxxxxxxxxxx -Interactive

    # Get all lists and libraries
	Write-Host Iterating through lists for the  $SiteUrl site -ForegroundColor Magenta
    $lists = Get-PnPList

    foreach ($list in $lists) {
        # Get all views in the list
        $views = Get-PnPView -List $list
		Write-Host `t Iterating through views for the  $list.Title list -ForegroundColor Blue 
        foreach ($view in $views) {
			Write-Host `t `t Getting settings for the $view.Title view -ForegroundColor Green 
            # Prepare the output object with all view settings
            $output = [PSCustomObject]@{
                SiteUrl         = $SiteUrl
                ListTitle       = $list.Title
                ViewTitle       = $view.Title
                ViewUrl         = "$SiteUrl/_layouts/15/start.aspx#/Lists/$($list.Title)/$($view.Title)"
                ViewName        = $view.DefaultView
                Filters         = $view.ViewQuery
                VisibleColumns  = ($view.ViewFields | Out-String).Trim()
                ColumnOrder     = ($view.ViewFields | Out-String).Trim()
                Sorting         = $view.OrderBy
                GroupBy         = $view.GroupBy
                ItemLimit       = $view.RowLimit
                TabularView     = $view.TabularView
                Totals          = $view.Aggregations
                Style           = $view.ViewStyle
                Mobile          = $view.MobileView
            }

            # Export to CSV, appending to the file
            $output | Export-Csv -Path $CsvPath -Append -NoTypeInformation
        }
    }

    # Disconnect from the SharePoint site
    Disconnect-PnPOnline
}

# Example usage
Export-SharePointViewsToCSV -SiteUrl "https://tenantnamehere.sharepoint.com/sites/S2-ArchRx"

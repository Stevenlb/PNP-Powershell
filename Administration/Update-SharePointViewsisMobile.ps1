function Disable-SPOMobileViews {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SiteUrl,
        [switch]$IncludeSubsites
    )

    try {
        # Connect to SharePoint site using web login
        Write-Host "Connecting to SharePoint site: $SiteUrl" -ForegroundColor Yellow
        Connect-PnPOnline -Url $SiteUrl -UseWebLogin

        # Function to process a single site
        function Process-Site {
            param (
                [string]$CurrentSiteUrl
            )

            Write-Host "`nProcessing site: $CurrentSiteUrl" -ForegroundColor Cyan

            # Get all lists and libraries
            $lists = Get-PnPList | Where-Object { -not $_.Hidden }
            Write-Host "Found $($lists.Count) lists/libraries to process" -ForegroundColor Yellow

            foreach ($list in $lists) {
                Write-Host "`nProcessing list/library: $($list.Title)" -ForegroundColor White
                
                try {
                    # Get all views for the current list
                    $views = Get-PnPView -List $list
                    Write-Host "Found $($views.Count) views" -ForegroundColor Gray

                    foreach ($view in $views) {
                        try {
                            Write-Host "Processing view: $($view.Title)" -ForegroundColor Yellow
                            
                            # Use Set-PnPView with explicit parameters
                            Set-PnPView -List $list -Identity $view.Title -Values @{
                                MobileView = $false
                            }

                            Write-Host "Successfully disabled mobile view for: $($view.Title)" -ForegroundColor Green
                        }
                        catch {
                            Write-Host "Error processing view '$($view.Title)': $_" -ForegroundColor Red
                            Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
                            
                            # Try alternative method if the first one fails
                            try {
                                Write-Host "Attempting alternative method..." -ForegroundColor Yellow
                                $viewXml = $view.GetViewXml()
                                if ($viewXml -match 'MobileView="TRUE"') {
                                    $viewXml = $viewXml -replace 'MobileView="TRUE"', 'MobileView="FALSE"'
                                    $view.SetViewXml($viewXml)
                                    Invoke-PnPQuery
                                    Write-Host "Successfully updated view using alternative method" -ForegroundColor Green
                                }
                            }
                            catch {
                                Write-Host "Alternative method also failed: $_" -ForegroundColor Red
                            }
                        }
                    }
                }
                catch {
                    Write-Host "Error processing list/library '$($list.Title)': $_" -ForegroundColor Red
                }
            }
        }

        # Process current site
        Process-Site -CurrentSiteUrl $SiteUrl

        # Process subsites if requested
        if ($IncludeSubsites) {
            $subsites = Get-PnPSubWeb -Recurse
            foreach ($subsite in $subsites) {
                Write-Host "`nConnecting to subsite: $($subsite.Url)" -ForegroundColor Yellow
                Connect-PnPOnline -Url $subsite.Url -UseWebLogin
                Process-Site -CurrentSiteUrl $subsite.Url
            }
        }
    }
    catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        Disconnect-PnPOnline
        Write-Host "`nProcessing completed!" -ForegroundColor Green
    }
}

function Enable-SPOMobileViews {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SiteUrl,
        [switch]$IncludeSubsites
    )

    try {
        # Connect to SharePoint site using web login
        Write-Host "Connecting to SharePoint site: $SiteUrl" -ForegroundColor Yellow
        Connect-PnPOnline -Url $SiteUrl -UseWebLogin

        # Function to process a single site
        function Process-Site {
            param (
                [string]$CurrentSiteUrl
            )

            Write-Host "`nProcessing site: $CurrentSiteUrl" -ForegroundColor Cyan

            # Get all lists and libraries
            $lists = Get-PnPList | Where-Object { -not $_.Hidden }
            Write-Host "Found $($lists.Count) lists/libraries to process" -ForegroundColor Yellow

            foreach ($list in $lists) {
                Write-Host "`nProcessing list/library: $($list.Title)" -ForegroundColor White
                
                try {
                    # Get all views for the current list
                    $views = Get-PnPView -List $list
                    Write-Host "Found $($views.Count) views" -ForegroundColor Gray

                    foreach ($view in $views) {
                        try {
                            Write-Host "Processing view: $($view.Title)" -ForegroundColor Yellow
                            
                            # Use Set-PnPView with explicit parameters
                            Set-PnPView -List $list -Identity $view.Title -Values @{
                                MobileView = $true
                            }

                            Write-Host "Successfully disabled mobile view for: $($view.Title)" -ForegroundColor Green
                        }
                        catch {
                            Write-Host "Error processing view '$($view.Title)': $_" -ForegroundColor Red
                            Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
                            
                            # Try alternative method if the first one fails
                            try {
                                Write-Host "Attempting alternative method..." -ForegroundColor Yellow
                                $viewXml = $view.GetViewXml()
                                if ($viewXml -match 'MobileView="TRUE"') {
                                    $viewXml = $viewXml -replace 'MobileView="false"', 'MobileView="true"'
                                    $view.SetViewXml($viewXml)
                                    Invoke-PnPQuery
                                    Write-Host "Successfully updated view using alternative method" -ForegroundColor Green
                                }
                            }
                            catch {
                                Write-Host "Alternative method also failed: $_" -ForegroundColor Red
                            }
                        }
                    }
                }
                catch {
                    Write-Host "Error processing list/library '$($list.Title)': $_" -ForegroundColor Red
                }
            }
        }

        # Process current site
        Process-Site -CurrentSiteUrl $SiteUrl

        # Process subsites if requested
        if ($IncludeSubsites) {
            $subsites = Get-PnPSubWeb -Recurse
            foreach ($subsite in $subsites) {
                Write-Host "`nConnecting to subsite: $($subsite.Url)" -ForegroundColor Yellow
                Connect-PnPOnline -Url $subsite.Url -UseWebLogin
                Process-Site -CurrentSiteUrl $subsite.Url
            }
        }
    }
    catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
        Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        Disconnect-PnPOnline
        Write-Host "`nProcessing completed!" -ForegroundColor Green
    }
}

# Example usage:
 Enable-SPOMobileViews -SiteUrl "https://tenantnamehere.sharepoint.com/sites/SiteNameHere/"
# Disable-SPOMobileViews -SiteUrl "https://tenantnamehere.sharepoint.com/sites/SiteNameHere/" -IncludeSubsites

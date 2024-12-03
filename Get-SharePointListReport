function Get-SharePointListReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, 
                   Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="SharePoint site URL")]
        [string[]]$SiteUrl,
        
        [Parameter(Mandatory=$true,
                   HelpMessage="Output path for the CSV report")]
        [string]$OutputPath,
        
        [Parameter(Mandatory=$false,
                   HelpMessage="PSCredential object for authentication")]
        [System.Management.Automation.PSCredential]$Credentials,

        [Parameter(Mandatory=$false,
                   HelpMessage="Append to existing CSV file")]
        [switch]$Append,

        [Parameter(Mandatory=$false,
                   HelpMessage="Skip connection if already connected")]
        [switch]$UseExistingConnection
    )

    begin {
        # Import required module
        if (-not (Get-Module -Name PnP.PowerShell)) {
            try {
                Import-Module PnP.PowerShell -ErrorAction Stop
            }
            catch {
                throw "Unable to load PnP.PowerShell module. Please ensure it's installed. Error: $($_.Exception.Message)"
            }
        }

        # Initialize results array
        $allResults = @()

        # Verify output path
        try {
            $outputDir = Split-Path -Parent $OutputPath
            if (-not (Test-Path $outputDir)) {
                New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
            }
        }
        catch {
            throw "Unable to verify/create output directory. Error: $($_.Exception.Message)"
        }
    }

    process {
        foreach ($site in $SiteUrl) {
            Write-Verbose "Processing site: $site"
            
            try {
                # Connect to SharePoint site if needed
                if (-not $UseExistingConnection) {
                    if ($Credentials) {
                        Connect-PnPOnline -Url $site -Credentials $Credentials
                    }
                    else {
                        Connect-PnPOnline -Url $site -Interactive
                    }
                    Write-Verbose "Connected to SharePoint site: $site"
                }

                # Get all lists and libraries
                $lists = Get-PnPList
                Write-Verbose "Retrieved $($lists.Count) lists from site"

                foreach ($list in $lists) {
                    # Skip hidden lists and system lists
                    if (-not $list.Hidden) {
                        $listUrl = $list.DefaultViewUrl
                        $settingsUrl = "$site/_layouts/15/listedit.aspx?List={$($list.Id)}"

                        $resultObject = [PSCustomObject]@{
                            SiteUrl = $site
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

                        $allResults += $resultObject
                    }
                }

                Write-Verbose "Processed $($allResults.Count) non-hidden lists from site"
            }
            catch {
                Write-Error "Error processing site $site : $($_.Exception.Message)"
                continue
            }
            finally {
                if (-not $UseExistingConnection) {
                    Disconnect-PnPOnline
                    Write-Verbose "Disconnected from SharePoint site: $site"
                }
            }
        }
    }

    end {
        try {
            if ($allResults.Count -gt 0) {
                # Export results
                if ($Append -and (Test-Path $OutputPath)) {
                    $allResults | Export-Csv -Path $OutputPath -NoTypeInformation -Append
                    Write-Host "Successfully appended $($allResults.Count) items to: $OutputPath" -ForegroundColor Green
                }
                else {
                    $allResults | Export-Csv -Path $OutputPath -NoTypeInformation
                    Write-Host "Successfully exported $($allResults.Count) items to: $OutputPath" -ForegroundColor Green
                }
            }
            else {
                Write-Warning "No results were found to export"
            }
        }
        catch {
            throw "Error exporting results: $($_.Exception.Message)"
        }
    }
}

# Example usage functions
function Get-MultiSiteListReport {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$SiteUrls,
        [string]$OutputPath = ".\SharePointListReport.csv"
    )
    
    foreach ($site in $SiteUrls) {
        Get-SharePointListReport -SiteUrl $site -OutputPath $OutputPath -Append
    }
}

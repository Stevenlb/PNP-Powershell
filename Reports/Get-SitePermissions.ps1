# Load configuration from an external script file
. .\config\scriptpaths.ps1

# Create a 'Reports' directory in the script path, force creation if it already exists
New-Item -ItemType Directory -Force -Path "$ScriptPath\Reports\"

# Clear the console screen
cls

# Record the start time of the script execution
$StartTime = Get-Date
Write-Host "Script Start time is $StartTime"

# Function to get permissions applied on a particular SharePoint object (Web, List, or Folder)
Function Get-PnPPermissions([Microsoft.SharePoint.Client.SecurableObject]$Object) {
    # Determine the type of the object and set relevant properties
    Switch($Object.TypedObject.ToString()) {
        "Microsoft.SharePoint.Client.Web"  { $ObjectType = "Site" ; $ObjectURL = $Object.URL; $ObjectTitle = $Object.Title }
        "Microsoft.SharePoint.Client.ListItem" {
            $ObjectType = "Folder"
            # Get the Folder property of the ListItem
            $Folder = Get-PnPProperty -ClientObject $Object -Property Folder
            $ObjectTitle = $Object.Folder.Name
            # Construct the full URL of the folder
            $ObjectURL = $("{0}{1}" -f $Web.Url.Replace($Web.ServerRelativeUrl,''),$Object.Folder.ServerRelativeUrl)
        }
        Default {
            $ObjectType = $Object.BaseType
            $ObjectTitle = $Object.Title
            # Get the RootFolder property of the List
            $RootFolder = Get-PnPProperty -ClientObject $Object -Property RootFolder    
            # Construct the full URL of the list
            $ObjectURL = $("{0}{1}" -f $Web.Url.Replace($Web.ServerRelativeUrl,''), $RootFolder.ServerRelativeUrl)
        }
    }
    
    # Get the HasUniqueRoleAssignments and RoleAssignments properties of the object
    Get-PnPProperty -ClientObject $Object -Property HasUniqueRoleAssignments, RoleAssignments
    $HasUniquePermissions = $Object.HasUniqueRoleAssignments
    
    $PermissionCollection = @()
    # Loop through each role assignment on the object
    Foreach($RoleAssignment in $Object.RoleAssignments) {
        # Get the RoleDefinitionBindings and Member properties of the role assignment
        Get-PnPProperty -ClientObject $RoleAssignment -Property RoleDefinitionBindings, Member
        $PermissionType = $RoleAssignment.Member.PrincipalType
        # Get the names of all permission levels assigned, excluding "Limited Access"
        $PermissionLevels = ($RoleAssignment.RoleDefinitionBindings | Select -ExpandProperty Name | Where { $_ -ne "Limited Access"}) -join "; "
        # Skip if no permissions are assigned
        If($PermissionLevels.Length -eq 0) {Continue}
        # Handle SharePoint groups differently from individual users
        If($PermissionType -eq "SharePointGroup") {
            # Get all members of the SharePoint group
            $GroupMembers = Get-PnPGroupMember -Identity $RoleAssignment.Member.LoginName
            # Skip empty groups
            If($GroupMembers.count -eq 0){Continue}
            # Get titles of all group members except "System Account"
            $GroupUsers = ($GroupMembers | Select -ExpandProperty Title | Where { $_ -ne "System Account"}) -join "; "
            If($GroupUsers.Length -eq 0) {Continue}
            # Create a new object to store permission information for the group
            $Permissions = New-Object PSObject
            $Permissions | Add-Member NoteProperty Object($ObjectType)
            $Permissions | Add-Member NoteProperty Title($ObjectTitle)
            $Permissions | Add-Member NoteProperty URL($ObjectURL)
            $Permissions | Add-Member NoteProperty HasUniquePermissions($HasUniquePermissions)
            $Permissions | Add-Member NoteProperty Users($GroupUsers)
            $Permissions | Add-Member NoteProperty Type($PermissionType)
            $Permissions | Add-Member NoteProperty Permissions($PermissionLevels)
            $Permissions | Add-Member NoteProperty GrantedThrough("SharePoint Group: $($RoleAssignment.Member.LoginName)")
            $PermissionCollection += $Permissions
        }
        Else {
            # Create a new object to store permission information for individual users
            $Permissions = New-Object PSObject
            $Permissions | Add-Member NoteProperty Object($ObjectType)
            $Permissions | Add-Member NoteProperty Title($ObjectTitle)
            $Permissions | Add-Member NoteProperty URL($ObjectURL)
            $Permissions | Add-Member NoteProperty HasUniquePermissions($HasUniquePermissions)
            $Permissions | Add-Member NoteProperty Users($RoleAssignment.Member.Title)
            $Permissions | Add-Member NoteProperty Type($PermissionType)
            $Permissions | Add-Member NoteProperty Permissions($PermissionLevels)
            $Permissions | Add-Member NoteProperty GrantedThrough("Direct Permissions")
            $PermissionCollection += $Permissions
        }
    }
    # Export the collected permissions to a CSV file, appending to existing data
    $PermissionCollection | Export-CSV $ReportFile -NoTypeInformation -Append
}

# Main function to get SharePoint Online site permissions report
Function Get-SitePermissions() {
[cmdletbinding()]
    Param (   
        [Parameter(Mandatory=$false)] [String] $SiteURL,     
        [Parameter(Mandatory=$false)] [switch] $Recursive,
        [Parameter(Mandatory=$false)] [switch] $ScanFolders,
        [Parameter(Mandatory=$false)] [switch] $IncludeInheritedPermissions
    ) 
    Try {
        $StartTime = Get-Date
        # Connect to the SharePoint Online site
        Connect-PnPOnline -Url $SiteUrl -ClientId c6d631cb-09f6-42e6-bd44-ab4daafd7acd -Interactive
        # Get the Web object
        $Web = Get-PnPWeb
        Write-host -f Green "Getting SCAs"
        # Get Site Collection Administrators
        $SiteAdmins = Get-PnPSiteCollectionAdmin
        $SiteCollectionAdmins = ($SiteAdmins | Select -ExpandProperty Title) -join "; "
        # Create a new object to store Site Collection Administrators information
        $Permissions = New-Object PSObject
        $Permissions | Add-Member NoteProperty Object("Site Collection")
        $Permissions | Add-Member NoteProperty Title($Web.Title)
        $Permissions | Add-Member NoteProperty URL($Web.URL)
        $Permissions | Add-Member NoteProperty HasUniquePermissions("TRUE")
        $Permissions | Add-Member NoteProperty Users($SiteCollectionAdmins)
        $Permissions | Add-Member NoteProperty Type("Site Collection Administrators")
        $Permissions | Add-Member NoteProperty Permissions("Site Owner")
        $Permissions | Add-Member NoteProperty GrantedThrough("Direct Permissions")
        # Generate a timestamp for the report file name
        $TimeStamp = Get-Date -Format "yyyyMMdd-HHmm"
        # Construct the report file path
        $ReportFile = $SiteURL -replace "https://ptportal.sharepoint.com/sites/", "$ScriptPath\Reports\"
        $ReportFile = $ReportFile -replace "/", ""
        $ReportFile = "$ReportFile-Permissions=$TimeStamp.csv"
        # Export Site Collection Administrators information to the CSV file
        $Permissions | Export-CSV $ReportFile -NoTypeInformation

        # Function to get permissions of folders in a given list
        Function Get-PnPFolderPermission([Microsoft.SharePoint.Client.List]$List) {
            Write-host "`t "$List.Title
            # Get all items from the list
            $ListItems = Get-PnPListItem -List $List -PageSize 2000
            # Filter for folder items, excluding "Forms" folder and folders starting with "_"
            $Folders = $ListItems | Where { ($_.FileSystemObjectType -eq "Folder") -and ($_.FieldValues.FileLeafRef -ne "Forms") -and (-Not($_.FieldValues.FileLeafRef.StartsWith("_")))}
            $ItemCounter = 0
            # Loop through each folder
            ForEach($Folder in $Folders) {
                # Check permissions based on whether to include inherited permissions
                If($IncludeInheritedPermissions) {
                    Get-PnPPermissions -Object $Folder
                }
                Else {
                    # Check if folder has unique permissions
                    $HasUniquePermissions = Get-PnPProperty -ClientObject $Folder -Property HasUniqueRoleAssignments
                    If($HasUniquePermissions -eq $True) {
                        Get-PnPPermissions -Object $Folder
                    }
                }
                $ItemCounter++
                # Show progress
                Write-Progress -PercentComplete ($ItemCounter / ($Folders.Count) * 100) -Activity "Getting permissions for items in '$($List.Title)'" -Status "Item: '$($Folder.FieldValues.FileLeafRef)' at '$($Folder.FieldValues.FileRef)' ($ItemCounter of $($Folders.Count))" -Id 2 -ParentId 1
            }
        }

        # Function to get permissions of all lists from the given web
        Function Get-PnPListPermission([Microsoft.SharePoint.Client.Web]$Web) {
            # Get all lists from the web
            $Lists = Get-PnPProperty -ClientObject $Web -Property Lists
            # List of system lists to exclude
            $ExcludedLists = @("Access Requests","App Packages","appdata","appfiles","Apps in Testing","Cache Profiles","Composed Looks","Content and Structure Reports","Content type publishing error log","Converted Forms","Device Channels","Form Templates","fpdatasources","Get started with Apps for Office and SharePoint","List Template Gallery", "Long Running Operation Status","Maintenance Log Library", "Images", "site collection images","Master Docs","Master Page Gallery","MicroFeed","NintexFormXml","Quick Deploy Items","Relationships List","Reusable Content","Reporting Metadata", "Reporting Templates", "Search Config List","Site Assets","Preservation Hold Library","Site Pages", "Solution Gallery","Style Library","Suggested Content Browser Locations","Theme Gallery", "TaxonomyHiddenList","User Information List","Web Part Gallery","wfpub","wfsvc","Workflow History","Workflow Tasks", "Pages")
            $Counter = 0
            # Loop through each list
            ForEach($List in $Lists) {
                # Check if the list should be included
                If($List.Hidden -eq $False -and $ExcludedLists -notcontains $List.Title) {
                    $Counter++
                    # Show progress
                    Write-Progress -PercentComplete ($Counter / ($Lists.Count) * 100) -Activity "Current list: '$($List.Title)'" -Status "List $Counter of $($Lists.Count)" -Id 1
                    # Check folder permissions if ScanFolders switch is present
                    If($ScanFolders) {
                        Get-PnPFolderPermission -List $List
                    }
                    # Check list permissions based on whether to include inherited permissions
                    If($IncludeInheritedPermissions) {
                        Get-PnPPermissions -Object $List
                    }
                    Else {
                        # Check if list has unique permissions
                        $HasUniquePermissions = Get-PnPProperty -ClientObject $List -Property HasUniqueRoleAssignments
                        If($HasUniquePermissions -eq $True) {
                            Get-PnPPermissions -Object $List
                        }
                    }
                }
            }
        }

        # Function to get web's permissions from given URL
        Function Get-PnPWebPermission([Microsoft.SharePoint.Client.Web]$Web) {
            Write-host -f Green "Getting Permissions for site."
            # Get permissions of the web
            Get-PnPPermissions -Object $Web
            Write-host -f Green "Getting Permissions of Lists and Libraries."
            # Get permissions of lists in the web
            Get-PnPListPermission($Web)
            # If Recursive switch is present, get permissions from all sub-webs
            If($Recursive) {
                # Get all sub-webs
                $Subwebs = Get-PnPProperty -ClientObject $Web -Property Webs
                # Loop through each sub-web
                Foreach ($Subweb in $web.Webs) {
                    # Check permissions based on whether to include inherited permissions
                    If($IncludeInheritedPermissions) {
                        Get-PnPWebPermission($Subweb)
                    }
                    Else {
                        # Check if sub-web has unique permissions
                        $HasUniquePermissions = Get-PnPProperty -ClientObject $SubWeb -Property HasUniqueRoleAssignments
                        If($HasUniquePermissions -eq $true) {
                            Get-PnPWebPermission($Subweb)
                        }
                    }
                }
            }
        }

        # Call the function with RootWeb to get site collection permissions
        Get-PnPWebPermission $Web
        Write-host -f Green "`n*** Site Permission Report Generated Successfully!***"
    }
    Catch {
        write-host -f Red "Error Generating Site Permission Report!" $_.Exception.Message
    }
    # Calculate and output the total runtime of the script
    $EndTime = Get-Date
    $diff= New-TimeSpan -Start $StartTime -End $EndTime
    Write-Output "Script Run Time: $diff"
}

# Call the main function with specific parameters
Get-SitePermissions -SiteURL "https://tenantnamehere.sharepoint.com/sites/Site" -Recursive -ScanFolders -IncludeInheritedPermissions

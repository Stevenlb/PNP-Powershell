#Call script with relative path variables
. .\config\scriptpaths.ps1

New-Item -ItemType Directory -Force -Path "$ScriptPath\Reports\"
cls

#Function to Get Permissions Applied on a particular Object, such as: Web, List or Folder
	$StartTime = Get-Date
	Write-Host "Script Start time is $StartTime"
Function Get-PnPPermissions([Microsoft.SharePoint.Client.SecurableObject]$Object)
{





	

	
    #Determine the type of the object
    Switch($Object.TypedObject.ToString())
    {
        "Microsoft.SharePoint.Client.Web"  { $ObjectType = "Site" ; $ObjectURL = $Object.URL; $ObjectTitle = $Object.Title }
        "Microsoft.SharePoint.Client.ListItem"
        {
            $ObjectType = "Folder"
            #Get the URL of the Folder
            $Folder = Get-PnPProperty -ClientObject $Object -Property Folder
            $ObjectTitle = $Object.Folder.Name
            $ObjectURL = $("{0}{1}" -f $Web.Url.Replace($Web.ServerRelativeUrl,''),$Object.Folder.ServerRelativeUrl)
        }
        Default
        {
            $ObjectType = $Object.BaseType #List, DocumentLibrary, etc
            $ObjectTitle = $Object.Title
            #Get the URL of the List or Library
            $RootFolder = Get-PnPProperty -ClientObject $Object -Property RootFolder    
            $ObjectURL = $("{0}{1}" -f $Web.Url.Replace($Web.ServerRelativeUrl,''), $RootFolder.ServerRelativeUrl)
        }
    }
    
    #Get permissions assigned to the object
    Get-PnPProperty -ClientObject $Object -Property HasUniqueRoleAssignments, RoleAssignments
  
    #Check if Object has unique permissions
    $HasUniquePermissions = $Object.HasUniqueRoleAssignments
      
    #Loop through each permission assigned and extract details
    $PermissionCollection = @()
    Foreach($RoleAssignment in $Object.RoleAssignments)
    {
        #Get the Permission Levels assigned and Member
        Get-PnPProperty -ClientObject $RoleAssignment -Property RoleDefinitionBindings, Member
  
        #Get the Principal Type: User, SP Group, AD Group
        $PermissionType = $RoleAssignment.Member.PrincipalType
     
        #Get the Permission Levels assigned
        $PermissionLevels = $RoleAssignment.RoleDefinitionBindings | Select -ExpandProperty Name
  
        #Remove Limited Access
        $PermissionLevels = ($PermissionLevels | Where { $_ -ne "Limited Access"}) -join "; "
  
        #Leave Principals with no Permissions assigned
        If($PermissionLevels.Length -eq 0) {Continue}
  
        #Check if the Principal is SharePoint group
        If($PermissionType -eq "SharePointGroup")
        {
            #Get Group Members
            $GroupMembers = Get-PnPGroupMember -Identity $RoleAssignment.Member.LoginName
                  
            #Leave Empty Groups
            If($GroupMembers.count -eq 0){Continue}
            $GroupUsers = ($GroupMembers | Select -ExpandProperty Title | Where { $_ -ne "System Account"}) -join "; "
            If($GroupUsers.Length -eq 0) {Continue}
 
            #Add the Data to Object
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
        Else #User
        {
            #Add the Data to Object
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
    #Export Permissions to CSV File
    $PermissionCollection | Export-CSV $ReportFile -NoTypeInformation -Append
}
    
#Function to get sharepoint online site permissions report
Function Get-SitePermissions()
{
[cmdletbinding()]
 
    Param 
    (   
        [Parameter(Mandatory=$false)] [String] $SiteURL,     
        [Parameter(Mandatory=$false)] [switch] $Recursive,
        [Parameter(Mandatory=$false)] [switch] $ScanFolders,
        [Parameter(Mandatory=$false)] [switch] $IncludeInheritedPermissions
    ) 
    Try {
			$StartTime = Get-Date
        #Connect to the Site
        Connect-PnPOnline -Url $SiteUrl -ClientId c6d631cb-09f6-42e6-bd44-ab4daafd7acd -Interactive
		
        #Get the Web
        $Web = Get-PnPWeb
  
        Write-host -f Yellow "Getting Site Collection Administrators..."
        #Get Site Collection Administrators
        $SiteAdmins = Get-PnPSiteCollectionAdmin
        Write-host log: Got admins
		
        $SiteCollectionAdmins = ($SiteAdmins | Select -ExpandProperty Title) -join "; "
        #Add the Data to Object
        $Permissions = New-Object PSObject
        $Permissions | Add-Member NoteProperty Object("Site Collection")
        $Permissions | Add-Member NoteProperty Title($Web.Title)
        $Permissions | Add-Member NoteProperty URL($Web.URL)
        $Permissions | Add-Member NoteProperty HasUniquePermissions("TRUE")
        $Permissions | Add-Member NoteProperty Users($SiteCollectionAdmins)
        $Permissions | Add-Member NoteProperty Type("Site Collection Administrators")
        $Permissions | Add-Member NoteProperty Permissions("Site Owner")
        $Permissions | Add-Member NoteProperty GrantedThrough("Direct Permissions")
		
                	$TimeStamp = Get-Date -Format "yyyyMMdd-HHmm"
$ReportFile = $SiteURL -replace "https://ptportal.sharepoint.com/sites/", "$ScriptPath\Reports\"

$ReportFile = $ReportFile -replace "/", ""
$ReportFile = "$ReportFile-Permissions=$TimeStamp.csv"
        #Export Permissions to CSV File

        $Permissions | Export-CSV $ReportFile -NoTypeInformation
Write-host "`t `t Getting Permissions for:"
        #Function to Get Permissions of Folders in a given List
        Function Get-PnPFolderPermission([Microsoft.SharePoint.Client.List]$List)
        {
            Write-host "`t `t `t "$List.Title
             
            #Get All Folders from List
            $ListItems = Get-PnPListItem -List $List -PageSize 2000
            $Folders = $ListItems | Where { ($_.FileSystemObjectType -eq "Folder") -and ($_.FieldValues.FileLeafRef -ne "Forms") -and (-Not($_.FieldValues.FileLeafRef.StartsWith("_")))}
 
            $ItemCounter = 0
            #Loop through each Folder
            ForEach($Folder in $Folders)
            {
                #Get Objects with Unique Permissions or Inherited Permissions based on 'IncludeInheritedPermissions' switch
                If($IncludeInheritedPermissions)
                {
                    Get-PnPPermissions -Object $Folder
                }
                Else
                {
                    #Check if Folder has unique permissions
                    $HasUniquePermissions = Get-PnPProperty -ClientObject $Folder -Property HasUniqueRoleAssignments
                    If($HasUniquePermissions -eq $True)
                    {
                        #Call the function to generate Permission report
                        Get-PnPPermissions -Object $Folder
                    }
                }
                $ItemCounter++
                Write-Progress -PercentComplete ($ItemCounter / ($Folders.Count) * 100) -Activity "Getting Permissions of Folders in List '$($List.Title)'" -Status "Processing Folder '$($Folder.FieldValues.FileLeafRef)' at '$($Folder.FieldValues.FileRef)' ($ItemCounter of $($Folders.Count))" -Id 2 -ParentId 1
            }
        }
  
        #Function to Get Permissions of all lists from the given web
        Function Get-PnPListPermission([Microsoft.SharePoint.Client.Web]$Web)
        {
            #Get All Lists from the web
            $Lists = Get-PnPProperty -ClientObject $Web -Property Lists
    
            #Exclude system lists
            $ExcludedLists = @("Access Requests","App Packages","appdata","appfiles","Apps in Testing","Cache Profiles","Composed Looks","Content and Structure Reports","Content type publishing error log","Converted Forms",
            "Device Channels","Form Templates","fpdatasources","Get started with Apps for Office and SharePoint","List Template Gallery", "Long Running Operation Status","Maintenance Log Library", "Images", "site collection images"
            ,"Master Docs","Master Page Gallery","MicroFeed","NintexFormXml","Quick Deploy Items","Relationships List","Reusable Content","Reporting Metadata", "Reporting Templates", "Search Config List","Site Assets","Preservation Hold Library",
            "Site Pages", "Solution Gallery","Style Library","Suggested Content Browser Locations","Theme Gallery", "TaxonomyHiddenList","User Information List","Web Part Gallery","wfpub","wfsvc","Workflow History","Workflow Tasks", "Pages")
              
            $Counter = 0
            #Get all lists from the web  
            ForEach($List in $Lists)
            {
                #Exclude System Lists
                If($List.Hidden -eq $False -and $ExcludedLists -notcontains $List.Title)
                {
                    $Counter++
                    Write-Progress -PercentComplete ($Counter / ($Lists.Count) * 100) -Activity "Current list: '$($List.Title)' in $($Web.URL)" -Status "Processing Lists $Counter of $($Lists.Count)" -Id 1
  
                    #Get Item Level Permissions if 'ScanFolders' switch present
                    If($ScanFolders)
                    {
                        #Get Folder Permissions
                        Get-PnPFolderPermission -List $List
                    }
  
                    #Get Lists with Unique Permissions or Inherited Permissions based on 'IncludeInheritedPermissions' switch
                    If($IncludeInheritedPermissions)
                    {
                        Get-PnPPermissions -Object $List
                    }
                    Else
                    {
                        #Check if List has unique permissions
                        $HasUniquePermissions = Get-PnPProperty -ClientObject $List -Property HasUniqueRoleAssignments
                        If($HasUniquePermissions -eq $True)
                        {
                            #Call the function to check permissions
                            Get-PnPPermissions -Object $List
                        }
                    }
                }
            }
        }
    
        #Function to Get Webs's Permissions from given URL
        Function Get-PnPWebPermission([Microsoft.SharePoint.Client.Web]$Web)
        {
            #Call the function to Get permissions of the web
            Write-host "Getting Permissions for $($Web.URL)"
            Get-PnPPermissions -Object $Web
    
            #Get List Permissions
            Write-host -f Yellow "`t Getting Permissions of Lists and Libraries..."
            Get-PnPListPermission($Web)
  
            #Recursively get permissions from all sub-webs based on the "Recursive" Switch
            If($Recursive)
            {
                #Get Subwebs of the Web
                $Subwebs = Get-PnPProperty -ClientObject $Web -Property Webs
  
                #Iterate through each subsite in the current web
                Foreach ($Subweb in $web.Webs)
                {
                    #Get Webs with Unique Permissions or Inherited Permissions based on 'IncludeInheritedPermissions' switch
                    If($IncludeInheritedPermissions)
                    {
                        Get-PnPWebPermission($Subweb)
                    }
                    Else
                    {
                        #Check if the Web has unique permissions
                        $HasUniquePermissions = Get-PnPProperty -ClientObject $SubWeb -Property HasUniqueRoleAssignments
    
                        #Get the Web's Permissions
                        If($HasUniquePermissions -eq $true)
                        {
                            #Call the function recursively                           
                            Get-PnPWebPermission($Subweb)
                        }
                    }
                }
            }
        }
  
        #Call the function with RootWeb to get site collection permissions
        Get-PnPWebPermission $Web
    
        Write-host -f Green "`n*** Site Permission Report Generated Successfully!***"
     }
    Catch {
        write-host -f Red "Error Generating Site Permission Report!" $_.Exception.Message
   }
   $EndTime = Get-Date
   $diff= New-TimeSpan -Start $StartTime -End $EndTime
Write-Output "Script Run Time: $diff"
}

 
Get-SitePermissions -SiteURL "https://ptportal.sharepoint.com/sites/PlanCP-QA-AHP" -Recursive -ScanFolders -IncludeInheritedPermissions

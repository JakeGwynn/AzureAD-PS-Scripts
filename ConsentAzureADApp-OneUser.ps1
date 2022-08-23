Connect-AzureAD
Connect-MgGraph -Scopes (
    "User.ReadBasic.All Application.ReadWrite.All " `
    + "DelegatedPermissionGrant.ReadWrite.All " `
    + "AppRoleAssignment.ReadWrite.All"
)


$ServicePrincipal = Get-AzureADServicePrincipal -All:$true | where-Object {$_.DisplayName -like "*microsoft graph powershell*"}

Get-AzureADServicePrincipalOAuth2PermissionGrant -ObjectId $ServicePrincipal.ObjectId -All:$true | FL

# The API to which access will be granted. Microsoft Graph Explorer makes API 
# requests to the Microsoft Graph API, so we'll use that here.
$resourceAppId = "00000003-0000-0000-c000-000000000000" # Microsoft Graph API
$permissions = @("openid", "profile", "offline_access", "User.Read", "User.ReadBasic.All")
$userUpnOrId = "user@example.com"

$clientAppId = $ServicePrincipal.AppId
$clientSp = Get-MgServicePrincipal -Filter "appId eq '$($clientAppId)'"
$user = Get-MgUser -UserId $userUpnOrId
$resourceSp = Get-MgServicePrincipal -Filter "appId eq '$($resourceAppId)'"
$scopeToGrant = $permissions -join " "
$grant = New-MgOauth2PermissionGrant -ResourceId $resourceSp.Id `
    -Scope $scopeToGrant `
    -ClientId $clientSp.Id `
    -ConsentType "Principal" `
    -PrincipalId $user.Id

$assignment = New-MgServicePrincipalAppRoleAssignedTo `
    -ServicePrincipalId $clientSp.Id `
    -ResourceId $clientSp.Id `
    -PrincipalId $user.Id `
    -AppRoleId "00000000-0000-0000-0000-000000000000"

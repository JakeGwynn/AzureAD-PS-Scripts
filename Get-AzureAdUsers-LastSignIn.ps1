<#
.SYNOPSIS
Export Azure AD SignInActivity & Manager
.DESCRIPTION
Connect to App registrations and Export Azure AD SignInActivity
.NOTES
Modified by Jake Gwynn
#>

[System.Net.ServicePointManager]::SecurityProtocol = 'TLS12'

# Application (client) ID, Directory (tenant) ID, and secret
$AppId = ""
$TenantId = ""
$ClientSecret = ""

$global:Stopwatch = $null
$global:Token = $null
function Connect-GraphApiWithClientSecret {
    Write-Host "Authenticating to Graph API"
    $Body = @{    
        Grant_Type    = "client_credentials"
        Scope         = "https://graph.microsoft.com/.default"
        client_Id     = $AppId
        Client_Secret = $ClientSecret
    }
    $ConnectGraph = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method POST -Body $Body
    $Global:Stopwatch =  [system.diagnostics.stopwatch]::StartNew()	
    return $ConnectGraph.access_token
}

# Get all users in source tenant
$uri = 'https://graph.microsoft.com/beta/users?$select=displayName,userPrincipalName,signInActivity'

# If the result is more than 999, we need to read the @odata.nextLink to show more than one side of users
$UserData = while (-not [string]::IsNullOrEmpty($uri)) {
    if($global:Stopwatch -eq $null -or $global:Stopwatch.elapsed.minutes -gt '55'){
        $global:Token = Connect-GraphApiWithClientSecret
    }
    $apiCall = try {
        Invoke-RestMethod -Headers @{Authorization = "Bearer $Token"} -Uri $uri -Method Get
    }
    catch {
        $errorMessage = $_.ErrorDetails.Message | ConvertFrom-Json
        Write-Host $errorMessage
    }
    $uri = $null
    if ($apiCall) {
        # Check if any data is left
        $uri = $apiCall.'@odata.nextLink'
        $apiCall
    }
}

# Set the result into an variable
$UserDataResults = ($UserData | select-object Value).Value
foreach ($User in $UserDataResults) {
    $UserUpn = $User.userPrincipalName
    if($global:Stopwatch -eq $null -or $global:Stopwatch.elapsed.minutes -gt '55'){
        $global:Token = Connect-GraphApiWithClientSecret
    }
    $ManagerUri = "https://graph.microsoft.com/v1.0/users/$($UserUpn)/manager" 
    $UserManager = $null
    try {
        $UserManager = Invoke-RestMethod -Headers @{Authorization = "Bearer $Token"} -Uri $ManagerUri -Method Get
        $User | Add-Member -Name "Manager" -MemberType NoteProperty -Value $UserManager.userPrincipalName -Force
    }
    catch {
        if ($_.Exception.Message -like "*404*") {
            $User | Add-Member -Name "Manager" -MemberType NoteProperty -Value "MANAGER NOT DEFINED" -Force
        }
        else {
            Write-Output "Error getting manager for user:"
            Write-Output $_.Exception.Message 
        }
    }
}
$Export = $null
$Export = $UserDataResults | Select-Object DisplayName,Manager,UserPrincipalName,@{n="LastLoginDate";e={[datetime]::Parse($_.signInActivity.lastSignInDateTime)}}

# Export and filter result based on domain name (Update the domainname)
# $Export | Where-Object {$_.userPrincipalName -match "YOURDOMAIN.COM"} | Select-Object DisplayName,Manager,UserPrincipalName,@{Name='LastLoginDate';Expression={[datetime]::Parse($_.LastLoginDate)}}

#Export data to CSV File    
$Export | Export-CSV -Path "C:\temp\AzureAdLastSignIn.csv" -NoTypeInformation
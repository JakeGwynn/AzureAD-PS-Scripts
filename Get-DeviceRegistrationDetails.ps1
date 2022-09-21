<#
Copyright 2022 Jake Gwynn
DISCLAIMER:
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>
[System.Net.ServicePointManager]::SecurityProtocol = 'TLS12'

$ClientSecret = ""
$TenantId = ""
$AppId = ""

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
function Get-RestApiError ($RestError) {
    if ($RestError.Exception.GetType().FullName -eq "System.Net.WebException") {
        $ResponseStream = $null
        $Reader = $null
        $ResponseStream = $RestError.Exception.Response.GetResponseStream()
        $Reader = New-Object System.IO.StreamReader($ResponseStream)
        $Reader.BaseStream.Position = 0
        $Reader.DiscardBufferedData()
        return $Reader.ReadToEnd();
    }
}
function Get-GraphDeviceRegistrationDetails ($DeviceOwner) {
    $ApiUrl = "https://graph.microsoft.com/v1.0/users/"+ $DeviceOwner + "/registeredDevices"
    try {
        $ApiCallResponse = (Invoke-RestMethod -Headers @{Authorization = "Bearer $Token"} -Uri $ApiUrl -Method Get)
        return $ApiCallResponse.value
    }
    catch {
        $RestError = $null
        $RestError = Get-RestApiError -RestError $_
        Write-Host $_ -ForegroundColor Red
        return Write-Host $RestError -ForegroundColor Red 
    }
}

$DeviceRegistrations = Get-AzureADUser -All $true  | ForEach-Object {
    if($global:Stopwatch -eq $null -or $global:Stopwatch.elapsed.minutes -gt '55'){
        $global:Token = Connect-GraphApiWithClientSecret
    }
    $DeviceOwner = $_.UserPrincipalName
    
    Get-GraphDeviceRegistrationDetails -DeviceOwner $DeviceOwner
} | Select-Object @{n="DeviceOwner";e={$DeviceOwner}},displayName,operatingSystem,approximateLastSignInDateTime,registrationDateTime,createdDateTime

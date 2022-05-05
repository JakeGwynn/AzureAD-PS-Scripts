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
    $script:ClientSecret = $null
    return $ConnectGraph.access_token
}

function Get-AzureAdSignInLogs-GraphApi {  
    [System.Collections.Generic.List[psobject]]$LogRecords = @()
    $LoopIteration = 0
    $CurrentBatchCount = 0
    $TotalProcessedCount = 0
    $GetMoreRecords = $true
    $ApiUrl = "https://graph.microsoft.com/v1.0/auditLogs/signIns"
    While ($GetMoreRecords -eq $true) {
        $LoopIteration++
        $ApiCallResponse = $null
        if($global:Stopwatch -eq $null -or $global:Stopwatch.elapsed.minutes -gt '55'){
            $global:Token = Connect-GraphApiWithClientSecret
        }
        try {
            $ApiCallResponse = (Invoke-RestMethod -Headers @{Authorization = "Bearer $Token"} -Uri $ApiUrl -Method Get)
        }
        catch {
            Start-Sleep -Seconds 10
            $ApiCallResponse = (Invoke-RestMethod -Headers @{Authorization = "Bearer $Token"} -Uri $ApiUrl -Method Get)
        }
        $CurrentBatchCount = $ApiCallResponse.Value.Count
        $TotalProcessedCount += $CurrentBatchCount
        $ApiUrl = $null
        $ApiUrl = $ApiCallResponse.'@odata.nextLink'
        If ($null -eq $apiUrl) {
            $GetMoreRecords = $false
        } 
        else {
            $GetMoreRecords = $true
        }
        [System.Collections.Generic.List[psobject]]$LogBatch = @()
        [System.Collections.Generic.List[psobject]]$LogBatch = $ApiCallResponse.Value
        $LogRecords.AddRange($LogBatch)
        Write-Host "Batch $LoopIteration finished. Records Processed:" -ForegroundColor Gray
        Write-Host "    This Batch Record Count: $CurrentBatchCount" -BackgroundColor DarkGreen -ForegroundColor Black
        Write-Host "    Total Record Count: $TotalProcessedCount" -BackgroundColor Yellow -ForegroundColor Black
    }
    Write-Host "Finished processing all Log Records"
    return $LogRecords
}

$AzureAdLogs = Get-AzureAdSignInLogs-GraphApi

$AzureAdLogs | Export-CSV -Path "C:\Temp\AzureAdSignInLogs.csv" -NoTypeInformation
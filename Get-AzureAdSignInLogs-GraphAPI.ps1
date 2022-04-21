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
        $ApiCallResponse = (Invoke-RestMethod -Headers @{Authorization = "Bearer $Token"} -Uri $ApiUrl -Method Get)
        $CurrentBatchCount = $ApiCallResponse.Value.Count
        $TotalProcessedCount += $CurrentBatchCount
        $apiUrl = $ApiCallResponse.'@odata.nextLink'
        If ($null -eq $apiUrl) {
        $GetMoreRecords = $false
        } else {
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

$TenantId = ""
$AppId = ""
$ClientSecret = ""

$Token = Connect-GraphApiWithClientSecret
$AzureAdLogs = Get-AzureAdSignInLogs-GraphApi

$AzureAdLogs
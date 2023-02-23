$CsvExportPath = "C:\temp\AllBookingsDirectLicenseAssignments.csv"

Connect-MsolService

[System.Collections.Generic.List[psobject]]$DirectBookingsAssignments = @()
$LicenseTable = Invoke-RestMethod -Uri "https://download.microsoft.com/download/e/3/e/e3e9faf2-f28b-490a-9ada-c6089a1fc5b0/Product%20names%20and%20service%20plan%20identifiers%20for%20licensing.csv" | ConvertFrom-Csv
$AllUsers = Get-MsolUser -All:$true

foreach ($User in $AllUsers) {
    # Iterate through each user license
    foreach ($License in $User.Licenses){
        # Only report on directly assigned user licenses
        if(($License.GroupsAssigningLicense[0] -eq $User.ObjectId) -or ($null -eq $License.GroupsAssigningLicense[0])){
            # Only report on license plans with Microsoft Bookings enabled 
            if(($License.ServiceStatus | Where-Object {$_.ServicePlan.ServiceName -match "MICROSOFTBOOKINGS"}).ProvisioningStatus -eq "Success") {
                # Add object to list of users that have direct bookings assignments
                $DirectBookingsAssignments.Add(
                    [PSCustomObject]@{
                        UserDisplayName = $User.DisplayName
                        UserPrincipalName = $user.UserPrincipalName
                        UserObjectId = $User.ObjectId
                        LicenseSku = $License.AccountSkuId
                        LicenseName = ($LicenseTable | Where-Object {$_.String_Id -eq $License.AccountSku.SkuPartNumber})[0].Product_Display_Name
                        BookingsEnabled = $true
                    }
                )
            }
            #Set-MsolUserLicense -UserPrincipalName $user.UserPrincipalName -RemoveLicenses $license.AccountSkuId
        }
    }
}
$DirectBookingsAssignments | Export-CSV -Path $CsvExportPath -NoTypeInformation

# Disconnect from MSOL Service
[Microsoft.Online.Administration.Automation.ConnectMsolService]::ClearUserSessionState()
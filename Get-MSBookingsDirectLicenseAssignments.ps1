<#
    Copyright 2022 Jake Gwynn

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), 
    to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
    and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>

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
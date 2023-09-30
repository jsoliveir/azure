$ErrorActionPreference = "Stop"

Select-AzSubscription -Subscription Platform

$FromResourceGroup = ""
$FromSqlServer = "" 

$ToResourceGroup = ""
$ToSqlServer = ""

$databases = Get-AzSqlDatabase `
    -ResourceGroupName $FromResourceGroup `
    -Server $FromSqlServer `
| Where-Object DatabaseName -NotLike master 

foreach ( $db in $databases) {
    $Existing = Get-AzSqlDatabase -DatabaseName $db.DatabaseName -ServerName $ToSqlServer -ResourceGroupName $ToResourceGroup -ErrorAction Ignore
    if($Existing) {
        Write-Host "Renaming target Database $($db.DatabaseName) from $ToSqlServer" -F cyan
        Set-AzSqlDatabase `
            -NewName "$($db.DatabaseName)-$(Get-Date -Format "yyyyMMddhhmmss")" `
            -ResourceGroupName $ToResourceGroup `
            -DatabaseName $db.DatabaseName `
            -ServerName $ToSqlServer
    }

    Write-Host "Copying Database $($db.DatabaseName) from $FromSqlServer to $ToSqlServer" -F cyan
    New-AzSqlDatabaseCopy `
        -ResourceGroupName $FromResourceGroup `
        -ServerName $FromSqlServer `
        -DatabaseName $db.DatabaseName `
        -CopyResourceGroupName $ToResourceGroup `
        -CopyServerName $ToSqlServer `
        -CopyDatabaseName $db.DatabaseName
} 
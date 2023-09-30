Function Remove-SqlDatabaseUser {
  param(
    [Parameter(Mandatory)] [String] $ServerName,
    [Parameter(Mandatory)] [String] $Database,
    [Parameter(Mandatory)] [String] $Username 
  )
  $ErrorActionPreference = "Stop"

  $AccessToken = (az account get-access-token --resource "https://database.windows.net" --query "accessToken" -o tsv)

  $Script = "
    IF EXISTS (SELECT * FROM dbo.sysusers WHERE name = '$Username')
      BEGIN
        DROP USER [$Username]
      END 
  "

  Write-Host -F Red "Removing user [$Username] from [$Database] ..."
  Invoke-Sqlcmd -ServerInstance "${ServerName}.database.windows.net,1433" `
    -AbortOnError:($ErrorActionPreference -notlike "stop") `
    -WarningAction SilentlyContinue `
    -AccessToken $AccessToken `
    -OutputSQLErrors $true `
    -Database $Database `
    -EncryptConnection `
    -Query $Script `
    -ErrorLevel 0 `
    -Verbose
}
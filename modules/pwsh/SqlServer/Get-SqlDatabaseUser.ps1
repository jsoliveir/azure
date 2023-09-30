Function Get-SqlDatabaseUser {
  param(
    [Parameter(Mandatory)] [String] $ServerName,
    [Parameter(Mandatory)] [String] $Database
  )
  $ErrorActionPreference = "Stop"

  $AccessToken = (az account get-access-token --resource "https://database.windows.net" --query "accessToken" -o tsv)

  $Script = "SELECT * FROM dbo.sysusers where islogin=1 and hasdbaccess=1"

  Invoke-Sqlcmd -ServerInstance "${ServerName}.database.windows.net,1433" `
    -WarningAction SilentlyContinue `
    -AccessToken $AccessToken `
    -OutputSQLErrors $true `
    -Database $Database `
    -EncryptConnection `
    -Query $Script `
    -ErrorLevel 0 `
    -AbortOnError `
    -Verbose
}
Function Get-SqlDatabaseUserPermissions {
  param(
    [Parameter(Mandatory)] [String] $ServerName,
    [Parameter(Mandatory)] [String] $Database,
    [Parameter(Mandatory)] [String] $Username
  )
  $ErrorActionPreference = "Stop"

  $AccessToken = (az account get-access-token --resource "https://database.windows.net" --query "accessToken" -o tsv)

  $Script = "
    SELECT  princ.name
    ,       princ.type_desc
    ,       perm.permission_name
    ,       perm.state_desc
    ,       perm.class_desc
    ,       object_name(perm.major_id)
    FROM    sys.database_principals princ
    LEFT JOIN
            sys.database_permissions perm
    ON      perm.grantee_principal_id = princ.principal_id
    WHERE name = '$Username'
  "
  Invoke-Sqlcmd -ServerInstance "${ServerName}.database.windows.net,1433" `
    -WarningAction SilentlyContinue `
    -ErrorAction Continue `
    -AccessToken $AccessToken `
    -OutputSQLErrors $true `
    -Database $Database `
    -EncryptConnection `
    -Query $Script `
    -ErrorLevel 0 `
    -AbortOnError `
    -Verbose
}
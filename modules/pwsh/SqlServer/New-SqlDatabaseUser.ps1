Function New-SqlDatabaseUser {
  param(
    [Parameter(Mandatory)] [String] $ServerName,
    [Parameter(Mandatory)] [String] $Database,
    [Parameter(Mandatory)] [String] $Username,   
    [Parameter()] [String[]] $Grants = @(),
    [Parameter()] [String] $Password
  )
  $ErrorActionPreference = "Stop"

  $AccessToken = (az account get-access-token --resource "https://database.windows.net" --query "accessToken" -o tsv)
  
  $Permissions = Get-SqlDatabaseUserPermissions `
    -ServerName $ServerName `
    -Database $Database `
    -Username $Username

  $Script = "
    BEGIN TRAN
    -- 
    IF EXISTS (SELECT * FROM dbo.sysusers WHERE name = '$Username')
      BEGIN
        IF '$Password' <> ''
          ALTER USER [$Username]  WITH PASSWORD = '$Password'
      END
    ELSE
      BEGIN
        IF '$Password' <> ''
          CREATE USER [$Username]  WITH PASSWORD = '$Password'
        ELSE
          CREATE USER [$Username] FROM EXTERNAL PROVIDER
      END
    GO
    
    $($Permissions | Where-Object permission_name -notin $Grants | ForEach-Object {
      if($Database -notlike "master") {
        "REVOKE $($_.permission_name) TO [$Username]"
      }
    })

    $($Grants | ForEach-Object {
      if($Database -notlike "master") {
        "GRANT $_ TO [$Username]"
      }
    })
    --
    COMMIT TRAN
  "

  Write-Host -F Yellow "Ensuring user $Username permissions on [$Database] ..."
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

  if ($Password) {
    return [PSCustomObject]@{
      ConnectionString =
      "Server=tcp:${ServerName}.database.windows.net,1433;" +
      "User ID=${Username};" +
      "Password=${Password};" +
      "Initial Catalog=$($Database);" +
      "Persist Security Info=True;" +
      "MultipleActiveResultSets=False;" +
      "TrustServerCertificate=false;" +
      "Connection Timeout=30;" +
      "Encrypt=True;"
    }
  }
}
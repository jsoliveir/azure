#!/usr/bin/env pwsh
<#
  Create/Update MSSQL Platform Service's users & passwords
#>

param ( 
  [Parameter()] $ModulesDir = "../../../modules",
  [Parameter(Mandatory)] $Configuration,
  [Parameter()] [Regex] $Filter = ".*"
)

Import-Module -Force  "$PSScriptRoot/$ModulesDir/pwsh/Azure.psm1"

$Config = Get-Content "$PSScriptRoot/$Configuration.yml" | ConvertFrom-Yaml 

$Ip = (Invoke-RestMethod "http://ipv4.icanhazip.com").Trim()

foreach ($Server in $Config.azure.mssql.servers.GetEnumerator()) {
  Set-AzSQLServerFirewallRule `
    -ServerName "$($Config.azure.resourceGroup)-$($Server.Name)" `
    -ResourceGroup $Config.azure.resourceGroup `
    -Subscription $Config.azure.subscription `
    -ErrorAction Stop `
    -Ip $Ip
}

foreach ($Database in $Config.azure.mssql.databases.GetEnumerator()) {
  if ($Database -notmatch $Filter) {
    continue
  }
  $Password = $(az account get-access-token --query accessToken -o tsv).Substring(0, 64)
  $Username = $Database.Name -replace ".*\.(.*)$", '$1'
  $Secret = "sql-db-$($Database.Name.ToLower() -replace "\W","-")" 
  $Credentials = New-SqlDatabaseUser `
    -ServerName "$($Config.azure.resourceGroup)-$($Database.Value.server)" `
    -Grants $Config.azure.mssql.serviceAccountPermissions `
    -Database $Database.Name `
    -Username $Username `
    -Password $Password

  Write-Host -F Cyan "Updating secret $Secret ..."
  az keyvault secret set --name "$Secret" --output none `
    --vault-name $Config.azure.resourceGroup `
    --value $Credentials.ConnectionString 

  $ExistingUsers = Get-SqlDatabaseUser `
    -ServerName "$($Config.azure.resourceGroup)-$($Database.Value.server)" `
    -WarningAction SilentlyContinue `
    -Database $Database.name `
  | Where-Object issqluser -eq 1 `
  | Where-Object name -ne "dbo"
  
  foreach ($User in $ExistingUsers) {
    if ($User.name -ne $Username) {
      Remove-SqlDatabaseUser `
        -ServerName "$($Config.azure.resourceGroup)-$($Database.Value.server)" `
        -WarningAction SilentlyContinue `
        -Database $Database.name `
        -Username $User.name `
    }
  }
}
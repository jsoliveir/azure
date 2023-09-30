#!/usr/bin/env pwsh
param ( 
  [Parameter()] $ModulesDir = "../../../modules",
  [Parameter()] $ErrorActionPreference = "Stop",
  [Parameter(Mandatory)] [String] $Configuration,
  [Parameter()] [String] $Parameters,
  [Parameter()] [Switch] $Confirm,
  [Parameter()] [Switch] $WhatIf
)

if (!(Get-Command "ConvertFrom-Yaml" -ErrorAction Ignore)){ 
  Install-Module powershell-yaml -Scope CurrentUser -Force 
}

Import-Module -Force @(
  "$PSScriptRoot/$ModulesDir/pwsh/Azure.psm1"
)

$Ip = (Invoke-RestMethod "http://ipv4.icanhazip.com").Trim()

$Config = Get-Content "$PSScriptRoot\$Configuration.yml" | ConvertFrom-Yaml

# SQL Users provisioning
foreach ($Server in $Config.azure.mssql.servers.GetEnumerator()) {
    Set-AzSQLServerFirewallRule `
      -ServerName "$($Config.azure.resourceGroup)-$($Server.Name)" `
      -ResourceGroup $Config.azure.resourceGroup `
      -Subscription $Config.azure.subscription `
      -ErrorAction Stop `
      -Ip $Ip
  }
  
  # Clean up existing users removed from the template
  foreach ($Server in $Config.azure.mssql.servers.GetEnumerator()) {
    $ExistingUsers = Get-SqlDatabaseUser `
      -ServerName "$($Config.azure.resourceGroup)-$($Server.Name)" `
      -Database master `
    | Where-Object issqluser -eq 0 `
    | Where-Object name -ne $Config.azure.mssql.adminGroup.name
  
    foreach ($User in $ExistingUsers) {
      
      if ($User.name -notin $Config.azure.mssql.aadAccessControl.GetEnumerator().Name) {
        Remove-SqlDatabaseUser `
          -ServerName "$($Config.azure.resourceGroup)-$($Server.Name)" `
          -Username $User.name `
          -Database master 
  
        foreach ($Database in $Config.azure.mssql.databases.GetEnumerator()) {
          Remove-SqlDatabaseUser `
            -ServerName "$($Config.azure.resourceGroup)-$($Server.Name)" `
            -Database $Database.Name `
            -Username $User.name
        }
      }
    }
  }
  
  # Create new user from template
  foreach ($User in $Config.azure.mssql.aadAccessControl.GetEnumerator()) {
    foreach ($Server in $Config.azure.mssql.servers.GetEnumerator()) {
      New-SqlDatabaseUser `
        -ServerName "$($Config.azure.resourceGroup)-$($Server.Name)" `
        -Username $User.Name `
        -Database master
    }
    foreach ($Database in $Config.azure.mssql.databases.GetEnumerator()) {
      New-SqlDatabaseUser `
        -ServerName "$($Config.azure.resourceGroup)-$($Database.Value.server)" `
        -Database $Database.Name `
        -Username $User.Name `
        -Grants $User.Value
    } 
  } 
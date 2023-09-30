#!/usr/bin/env pwsh
param ( 
  [Parameter()] $ModulesDir = "../../../modules",
  [Parameter()] $ErrorActionPreference = "Stop",
  [Parameter()] $Configuration = "main"
)

if (!(Get-Command "ConvertFrom-Yaml" -ErrorAction Ignore)){ 
  Install-Module powershell-yaml -Scope CurrentUser -Force 
}

Import-Module -Force @(
  "$PSScriptRoot/$ModulesDir/pwsh/Azure.psm1"
)

$Config = Get-Content "$PSScriptRoot/$Configuration.yml" | ConvertFrom-Yaml

foreach( $Secret in $Config.azure.keyvault.copyFrom ) {
  Write-Host -F Yellow "Copying $($Secret.secret) from $($Secret.keyvault) ..."
  $Value = $(az keyvault secret show `
    --subscription $Secret.subscription `
    --vault-name $Secret.keyvault  `
    --name $Secret.secret `
    -o json | ConvertFrom-Json)

  $PFXPath = $(Join-Path $PSScriptRoot $Secret.name) 
  $Value.value | Set-Content $PFXPath 

  az keyvault secret set `
    --vault-name $Config.azure.resourceGroup `
    --name $Secret.name  `
    --file $PFXPath | Out-Null
  
  Remove-Item $PFXPath
}
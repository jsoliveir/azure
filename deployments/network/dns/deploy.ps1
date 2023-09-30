#!/usr/bin/env pwsh
param ( 
  [Parameter()] $ModulesDir = "../../../modules",
  [Parameter()] $ErrorActionPreference = "Stop",
  [Parameter()] [String] $Template = "main.yml",
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

$Configurations = Get-Content $PSScriptRoot\$Template | ConvertFrom-Yaml

az group create `
  --subscription $Configurations.azure.subscription `
  --name $Configurations.azure.resourceGroup `
  --location $Configurations.azure.location `
  --output none

az role assignment delete -o none --ids $(
  az role assignment list `
    --resource-group $Configurations.azure.resourceGroup`
    --subscription $Configurations.azure.subscription `
    --query [].id `
    -o tsv
) 2> $null
  
foreach( $Assignment in $Configurations.azure.aadRoleAssingments){
  foreach( $Role in $Assignment.roles ){
    (Start-Job -Name "+ Ensuring Role $Role to $($Assignment.group)" -ScriptBlock {
      az role assignment create `
        --scope $(az group show --query id --name $using:Configurations.azure.resourceGroup --subscription $using:Configurations.azure.subscription) `
        --assignee-object-id $(az ad group show  --query id --group "$($using:Assignment.group)") `
        --assignee-principal-type "Group" `
        --role "$using:Role" `
        --output none
      if($LASTEXITCODE){
        throw "exited with status $LASTEXITCODE" 
      }      
    }).Name
  }
}

Get-Job | Receive-Job -Wait -AutoRemoveJob 
Get-Job | Remove-Job -Force

az stack sub create `
  --subscription $Configurations.azure.subscription `
  --name $Configurations.azure.resourceGroup `
  --location $Configurations.azure.location `
  --template-file "$PSScriptRoot/main.bicep" `
  --deny-settings-mode none `
  --output yaml `
  --delete-all `
  --yes

if($LASTEXITCODE) 
  {  throw "deployment has failed ($Errors)"}
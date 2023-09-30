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

$Configurations = Get-Content "$PSScriptRoot\$Configuration.yml" | ConvertFrom-Yaml

az group create `
  --subscription $Configurations.azure.subscription `
  --name $Configurations.azure.resourceGroup `
  --location $Configurations.azure.location `
  --output none

& $PSScriptRoot/deploy.role.assingments.ps1 -Configuration $Configuration 

az stack sub create `
  --subscription $Configurations.azure.subscription `
  --name $Configurations.azure.resourceGroup `
  --location $Configurations.azure.location `
  --template-file "$PSScriptRoot/main.bicep" `
  --parameters "environment=$Configuration" `
  --deny-settings-mode none `
  --output yaml `
  --delete-all `
  --yes

if($LASTEXITCODE) 
  { throw "Deployment has failed ($LASTEXITCODE)" }
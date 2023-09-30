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

az stack sub create `
  --subscription $Configurations.azure.subscription `
  --template-file "$PSScriptRoot/main.bicep" `
  --name "virtual-network-peerings" `
  --deny-settings-mode none `
  --location northeurope `
  --output yaml `
  --delete-all `
  --yes

if($LASTEXITCODE) 
  {  throw "deployment has failed ($Errors)"}
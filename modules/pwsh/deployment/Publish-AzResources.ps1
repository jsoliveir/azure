Function Publish-AzResources {
  param(
    [Parameter()] [ValidateSet('Subscription', 'ResourceGroup')] $Scope = "Subscription",
    [Parameter(Mandatory)] [System.IO.FileInfo] $TemplateFile,
    [Parameter(Mandatory)] [System.IO.FileInfo] $ConfigFile,
    [Parameter()] [String] $Location = "northeurope",
    [Parameter()] $ErrorActionPreference = "Stop",
    [Parameter()] [PSCustomObject] $Parameters = @{},
    [Parameter()] $ModulesDir = "../../",
    [Parameter()] [Switch] $WhatIf
  )

  $Config = Get-Content $ConfigFile.FullName | ConvertFrom-Json

  if (!$Config.version) {
    Write-Error "[version] must be defined in the config file"
  }

  if (!$Config.deployment -and !$Config.resourceGroup) {
    Write-Error "[deployment] or [resourceGroup] must be defined in the config file"
  }
    
  if (Get-Content $TemplateFile | Select-String "param\s+configuration\s+string") {
    $Parameters.Add("configuration", $ConfigFile.BaseName)
  }

  if (Get-Content $TemplateFile  | Select-String "param\s+adGroups\s+array") {
    $Parameters.Add("adGroups", @())
    az ad group list | ConvertFrom-Json | ForEach-Object {
      $Parameters["adGroups"] += @{ DisplayName = $_.displayName; Id = $_.id }
    }
  }
  
  if (Get-Content $TemplateFile | Select-String "param\s+subscriptions\s+object") {
    $Parameters.Add("subscriptions", @{})
    az account list | ConvertFrom-Json | ForEach-Object {
      $Parameters["subscriptions"].Add($_.name, $_.id)
    }
  }

  $ConvertedParams = @{}
  $Parameters.GetEnumerator().ForEach{ $ConvertedParams.Add($_.Name, @{value = $_.Value }) }
  $Parameters = $ConvertedParams

  $DeploymentName = @($Config.deployment, $Config.resourceGroup, $Config.version) `
    -notlike $null -join "-"

  #  Deploy the Infrastrucuture templates
  az deployment sub create  `
    --parameters "$($Parameters | ConvertTo-Json -Depth 10 -Compress)" `
    --subscription $Config.subscription `
    --name $DeploymentName.ToLower() `
    --template-file $TemplateFile `
    --location $Location `
    --verbose `
  | Out-Null
  
  if ($LASTEXITCODE) {
    Write-Error "Template deployment failed"
  }
  
  # Write-Host "Determining resources not affected by the template (orphaned)..."
  # Get-AzOrphanedResources `
  #   -ExcludeResourceTypes @("Microsoft.Network/networkInterfaces") `
  #   -ExcludeResourceNames @("*sql-*/master") `
  #   -ResourceGroupName $Config.resourceGroup `
  #   -Subscription $Config.subscription `
  # | Select-Object Name, ResourceType `
  # | Format-Table -AutoSize

}
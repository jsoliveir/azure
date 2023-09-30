function Set-AzStorageAccountFirewallRulesForCD {
  param(
    [Parameter(Mandatory)] $StorageAccountName,
    [Parameter(Mandatory)] $ResourceGroup,
    [Parameter(Mandatory)] $Subscription
  )

  $Ip = (Invoke-RestMethod "http://ipv4.icanhazip.com").Trim()

  Write-Host "Ensuring proper firewall rules for $Ip on $StorageAccountName ..."

  $StorageAccount =  (az storage account list `
    --resource-group $ResourceGroup `
    --subscription $Subscription `
  | ConvertFrom-Json) | Where-Object name -like $StorageAccountName
  
  if(!$StorageAccount)
  { return }

  $NetworkRules = az storage account network-rule list `
    --account-name $StorageAccountName `
    --resource-group $ResourceGroup `
    --subscription $Subscription `
  | ConvertFrom-Json

  foreach ($rule in $NetworkRules.ipRules.ipAddressOrRange) {
    az storage account network-rule remove `
      --account-name $StorageAccountName `
      --resource-group $ResourceGroup `
      --subscription $Subscription `
      --ip-address $rule `
    | Out-Null
  }

  az storage account network-rule add `
    --account-name $StorageAccountName `
    --resource-group $ResourceGroup `
    --subscription $Subscription `
    --ip-address $Ip `
  | Out-Null

  if ($LASTEXITCODE) {
    throw "error applying storage account rule on $StorageAccountName for $Ip"
  }
}
function Set-AzSQLServerFirewallRule {
  param(
    [Parameter()] $RuleName = "Deployment", 
    [Parameter(Mandatory)] $ResourceGroup,
    [Parameter(Mandatory)] $Subscription, 
    [Parameter(Mandatory)] $ServerName,
    [Parameter(Mandatory)] $Ip
  )

  Write-Host "Ensuring MSSQL Firewall Rules ($ServerName)"

  if (az sql server show `
      --resource-group $ResourceGroup  `
      --subscription $Subscription `
      --name $ServerName 
  ) {

    az sql server update `
      --resource-group $ResourceGroup  `
      --subscription $Subscription `
      --enable-public-network true `
      --name $ServerName `
      --output none

    az sql server firewall-rule create `
      --resource-group $ResourceGroup  `
      --subscription $Subscription `
      --start-ip-address $Ip `
      --end-ip-address $Ip `
      --server $ServerName `
      --name $RuleName `
      --output none

    if ($LASTEXITCODE) {
      exit 1;
    }
  }
}
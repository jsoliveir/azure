function New-SSLCertificate {
  param (
    [Parameter()] [String] $DnsZoneSubscriptionId = "4d3d4be8-eb80-4767-b9da-caa2bfb2abc1",
    [Parameter()] [String] $Subscription = "c8c63fd1-88d1-4d34-bfdd-632fbe12e963",
    [Parameter()] [String] $Contact = "devops@habitushealth.net",
    [Parameter()] [String] $PublicDnsZone = "habitushealth.net",
    [Parameter()] [String] $KeyVaultName = "habitus-vault-eu",
    [Parameter()] [String] $ErrorActionPreference = "Stop",
    [Parameter(Mandatory)] [String] $Domain,
    [Parameter()] [Switch] $Renew,
    [Parameter()] [Switch] $Force,
    [Parameter()] [Switch] $Test
  )

  if(!(Get-Command "New-PAAccount" -ErrorAction Ignore)){
    Install-Module -Name Posh-ACME -Scope CurrentUser -Force
  }

  $EAB = "KyD2qA_Y5kh1ZklJpXqc3A"
  $HMAC= "j-tPfcxrZjIUUTshutJH9DYr5V9mnAj0RipNagzDN_gyAByxmHMJcuG1_Fi3ZHm8TrB4tfKctUEvtOfO3JRISQ"
  $AppId= "52fe5f9a-bd3d-47f4-b1fc-24c5c772545f"
  $TenantId = "1c0ab84b-2635-4210-b7e5-a669da3b7e4d"
  
  if(!(Test-Path "$PSScriptRoot/acme.sh/account.conf" )){
    Write-Host "Acquiring new azure ad app secret ..."
    az ad app credential list --id $AppId `
      | ConvertFrom-Json `
      | Where-Object displayName -like "acme.sh" `
      | ForEach-Object {
        az ad app credential delete `
        --key-id $_.keyId `
        --id $AppId 
      }
    $AppSecret  = $(
      az ad app credential reset `
      --display-name "acme.sh" `
      --query "password" `
      --id $AppId `
      --output tsv `
      --append 
    )
    Start-Sleep -Seconds 45
  }

  Set-PAServer ZEROSSL_PROD
  New-PAAccount  `
    -Contact $Contact `
    -ExtAcctHMACKey $HMAC `
    -ExtAcctKID $EAB `
    -AcceptTOS `
    -Force

  $spPass = $AppSecret  | ConvertTo-SecureString -AsPlainText -Force
  $AppCred = [pscredential]::new($AppId,$spPass)
  $Certificate = New-PACertificate $Domain -DnsSleep 20 -Verbose `
    -PfxPass $AppSecret `
    -Plugin Azure `
    -PluginArgs @{
      AZSubscriptionId = "4d3d4be8-eb80-4767-b9da-caa2bfb2abc1" 
      AZTenantId = $TenantId 
      AZAppCred = $AppCred
    } 

  if($LASTEXITCODE -eq 1){
    Write-Error "Could not get the certificate"
  }

  $SecretName = ($Domain -replace "\W", "-") -replace "^\W+"
  Write-Host "Updating secret $SecretName ..."
  az keyvault certificate import `
    --file $Certificate.PfxFullChain `
    --subscription $Subscription `
    --vault-name $KeyVaultName `
    --password $AppSecret `
    --name $SecretName `
  | Out-Null
      
  if($LASTEXITCODE){
    Write-Error "Could not update secret $SecretName on $KeyVaultName ..."
  }

  Write-Host -F green "All Good :)"
}

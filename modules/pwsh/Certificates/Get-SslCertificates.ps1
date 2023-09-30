Function Get-SSLCertificates {
  param(
    [Parameter()][String] $KeyVaultName = "habitus-vault-eu",
    [Parameter()][String] $Subscription = "c8c63fd1-88d1-4d34-bfdd-632fbe12e963"
  )
  
  $Certificates = @()

  $Certificates += az keyvault secret list `
    --subscription $Subscription `
    --vault-name $KeyVaultName `
    --query "[?contentType=='application/x-pkcs12']" `
  | ConvertFrom-Json
  
  $Certificates += az keyvault certificate list `
  --subscription $Subscription `
  --vault-name $KeyVaultName `
  | ConvertFrom-Json

  $Result = @()

  foreach ($Certificate in $Certificates) {
    $CertificateData = az keyvault secret show --id ($Certificate.id -replace 'certificates','secrets') --query "value" -o tsv 
    $Expries = ($certificates[0].attributes.expires -as [datetime])
    $Result += [PSCustomObject] @{
      IsExpiring     = $Expries -lt (Get-Date).AddDays(30)
      HasExpired     = $Expries -lt (Get-Date)
      Domain         = $Certificate.name -replace "-", "."
      SecretId       = $Certificate.id
      Data           = $CertificateData
      Expires        = $Expries 
    }
  }
  return $Result
}
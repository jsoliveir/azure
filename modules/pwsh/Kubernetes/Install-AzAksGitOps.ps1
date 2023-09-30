Function Install-AzAksGitOps {
  param(
    [Parameter()] [String] $SshKeySecretName = "bitbucket-ssh-private-key",
    [Parameter(Mandatory)] [String] $KeyVaultName,
    [Parameter(Mandatory)] [String] $Subscription,
    [Parameter(Mandatory)] [String] $ResourceGroup,
    [Parameter(Mandatory)] [String] $RepositoryUrl,
    [Parameter(Mandatory)] [String] $RepositoryPath,
    [Parameter(Mandatory)] [String] $ClusterName,
    [Parameter()] [HashTable] $Variables
  )

  $ErrorActionPreference = "Stop"

  $WorkDir = "$PSScriptRoot/manifests"

  New-Item $WorkDir `
    -ItemType Directory `
    -ErrorAction Ignore `
  | Out-Null

  $GitSshKey = $(
    az keyvault secret show `
      --subscription $Subscription `
      --vault-name $KeyVaultName `
      --name $SshKeySecretName `
      --query "value" `
      --output tsv
  )
    
  if (!$GitSshKey) {
    Write-Error `
      "Missing secret $SshKeySecretName on keyvautl $KeyVaultName"
  }

  $GitSshKey | Set-Content $WorkDir/id_rsa

  Write-Host "Generating Kubernetes Manifest ..." `
    -ForegroundColor Yellow

  docker run -v "$WorkDir/:/src/" -v "$WorkDir/id_rsa:/root/.ssh/id_rsa" --user 0 --entrypoint bash bitnami/kubectl -c "
    apt update -qq &> /dev/null  && apt install -y -qq openssh-client &> /dev/null &&\
    ssh-keyscan -t rsa bitbucket.org >> `/root/.ssh/known_hosts && git clone $RepositoryUrl &&\
    kubectl kustomize ./$($RepositoryUrl | Split-Path -Leaf)/$($RepositoryPath -replace '^/') --enable-helm > /src/$ClusterName.yml 
  "

  if ($LASTEXITCODE) {
    Write-Error `
      "Cound not generate the manifest file"
  }

  Write-Host  "Configuring $CLusterName ..." `
    -ForegroundColor Cyan

  az aks command invoke `
    --command "kubectl apply -f $ClusterName.yml || kubectl apply -f $ClusterName.yml" `
    --file "$WorkDir/$ClusterName.yml" `
    --resource-group $ResourceGroup `
    --subscription $Subscription `
    --name $ClusterName `
  | Out-Null

  if ($LASTEXITCODE) {
    Write-Error `
      "Cluster configuration has failed"
  }
  
  Remove-Item "$WorkDir/" `
    -ErrorAction Ignore `
    -Recurse `
    -Force 

  Write-Host "All set :)" `
    -ForegroundColor Green 
}



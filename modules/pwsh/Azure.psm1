# Dependencies check
$ErrorActionPreference = "Stop"

if(!(Get-Command "git")) {
  exit 1
}

if(!(Get-Command "az")) {
  exit 1
}

if (!(Get-Command "Invoke-SqlCmd" -ErrorAction Ignore)) { 
  Install-Module SQLServer -Force
}

# Load module functions
Get-ChildItem $PSScriptRoot -Recurse -Filter "*.ps1" | ForEach-Object {
  . $_.FullName
}

try {
  $Session = az account show 2> $null | ConvertFrom-Json
}
finally {
  if (!$Session) {
    if (!$env:ARM_CLIENT_ID) {
      az login
    } 
    else {
      az login --service-principal `
        --password $env:ARM_CLIENT_SECRET `
        --username $env:ARM_CLIENT_ID `
        --tenant $env:ARM_TENANT_ID 
    }
  }
  if ($LASTEXITCODE) {
    Write-Error "az login has failed"
    exit 1
  }
}

# Export the module functions
Export-ModuleMember -Function *
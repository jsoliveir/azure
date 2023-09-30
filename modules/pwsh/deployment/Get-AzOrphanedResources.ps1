Function Get-AzOrphanedResources {
  param(
    [Parameter()] [String[]] $ExcludeResourceTypes = @(),
    [Parameter()] [String[]] $ExcludeResourceNames = @(),
    [Parameter()] [String] $ResourceGroupName = "*",
    [Parameter()] $ErrorActionPreference = "Stop",
    [Parameter()] [String] $Subscription,
    [Parameter()] $ModulesDir = "../../"
  )

  $Context = Get-AzContext

  if ($Subscription) {
    $Context = Get-AzContext -ListAvailable | Where-Object { 
      "$($_.Subscription.Name):$($_.Subscription.Id)" -match $Subscription 
    } | Select-Object -First 1
  }

  # List all orphaned resources (resources dettached from the template)
  $ResourceGroups = Get-AzResourceGroup -DefaultProfile $Context `
  | Where-Object ResourceGroupName -like "$ResourceGroupName"
  
  return $ResourceGroups | ForEach-Object { $ResourceGroup = $_
    Get-AzResource -DefaultProfile $Context -ResourceGroupName $ResourceGroup.ResourceGroupName `
    | Where-Object { $_.Tags.ref -ne $ResourceGroup.Tags.ref } `
    | Where-Object ResourceType -notin $ExcludeResourceTypes `
    | Where-Object Name -notin $ExcludeResourceNames 
  } 
}
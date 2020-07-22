# script to use to enable ASR with PPGs, currently only possible with Powershell

# target RG, vnet and ppg
$vmName = "ppgtest-eun-vm"  # your source VM that you want protect
$primaryLocation = "northeurope" 
$primaryRgName = "ppgtest-eun-rg"
$secondaryRgName = "asrppg-target-weu-rg" # MUST exist already
$secondaryLocation = "westeurope"
$secondaryVnetName = "asrppg-target-weu-vnet" # MUST exist already
$secondaryPpgName = "asrppg-target-weu-ppg"  # MUST exist already
$recoveryServicesVault = "Site-recovery-vault-westeurope" # name of your RSV you want to use

# set context to the specific RSV vault first
Get-AzRecoveryServicesVault -Name $recoveryServicesVault | Set-AzRecoveryServicesAsrVaultContext 

# Get step by step to fabric -> container -> containermaping and set in variable
# If you enabled recovery services vault and ASR for some VMs already, then all of this already exists and you just need the technical names
# First run AzRecoveryServicesAsrFabric , without any parameters -> pick the one which matches your source region
# Then add the Name of it, pipe to Get-AzRecoveryServicesAsrProtectionContainer
# If it makes sense, continue piping to Get-AzRecoveryServicesAsrProtectionContainerMapping and again pick the one which makes sense for primary region->secondary, add the Name and construct command as in below example
$asrMapping = Get-AzRecoveryServicesAsrFabric -Name "asr-a2a-default-northeurope" | Get-AzRecoveryServicesAsrProtectionContainer | Get-AzRecoveryServicesAsrProtectionContainerMapping -Name "northeurope-westeurope-24-hour-retention-policy"

# Get PPG id of DR-PPG (must exist)
$secondaryPpg = Get-AzProximityPlacementGroup -Name $secondaryPpgName -ResourceGroupName $secondaryRgName

# get source VM context
$VM = Get-AzVM -Name $vmName -ResourceGroupName $primaryRgName 

# Get the resource group that the virtual machine must be created in when failed over.
$secondaryRg = Get-AzResourceGroup -Name $secondaryRgName -Location $secondaryLocation

# kick off ASR job to enable VM protection
$TempASRJob = New-AzRecoveryServicesAsrReplicationProtectedItem -AzureToAzure -AzureVmId $VM.Id -Name (New-Guid).Guid -ProtectionContainerMapping $asrMapping -AzureToAzureDiskReplicationConfiguration $diskconfigs -RecoveryResourceGroupId $secondaryRg.ResourceId -RecoveryProximityPlacementGroupId $secondaryPpg.Id


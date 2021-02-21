#>
Function Set-Secrets {
    <#
    .SYNOPSIS
        Sets the Secrets in Azure Keyvault

    .DESCRIPTION
        Sets the secrets in Azure Keyvault that are required for the deployment automation

    .PARAMETER VirtualMachineName
        This is the name of the Virtual Machine.

    .PARAMETER ResourceGroupName
        This is the name of the resource group .

    .EXAMPLE 

    #
    #
    # Import the module
    Import-Module "SAPDeploymentUtilities.psd1"
    Set-Secrets -Environment PROD -Client_id <appId> -VaultName <vaultname> -Client_secret <clientsecret> -Tenant <TenantID> 

    
.LINK
    https://github.com/Azure/sap-hana

.NOTES
    v0.1 - Initial version

.

    #>
    <#
Copyright (c) Microsoft Corporation.
Licensed under the MIT license.
#>
    [cmdletbinding()]
    param(
        #Environment name
        [Parameter(Mandatory = $true)][string]$Environment,
        #Keyvault name
        [Parameter(Mandatory = $true)][string]$VaultName,
        # #SPN App ID
        [Parameter(Mandatory = $true)][string]$Client_id,
        #SPN App secret
        [Parameter(Mandatory = $true)][string]$Client_secret,
        #Tenant
        [Parameter(Mandatory = $true)][string]$Tenant
    )

    Write-Host -ForegroundColor green ""
    Write-Host -ForegroundColor green "Saving the secrets"

    $mydocuments = [environment]::getfolderpath("mydocuments")
    $filePath = $mydocuments + "\sap_deployment_automation.ini"
    $iniContent = Get-IniContent $filePath

    # Subscription
    $sub = $iniContent[$Environment]["Subscription"]

    Write-Host "Setting the secrets for " $Environment

    # Read keyvault
    $v = $iniContent[$Environment]["Vault"]

    Write-Host $v


    if ($VaultName -eq "") {
        if ($v -eq "" -or $null -eq $v) {
            $v = Read-Host -Prompt 'Keyvault:'
        }
    }
    else {
        $v = $VaultName
    }

    # Read SPN ID
    $spnid = $iniContent[$Environment]["Client_id"]

    if ($Client_id -eq "") {
        if ($spnid -eq "" -or $null -eq $spnid) {
            $spnid = Read-Host -Prompt 'SPN App ID:'
        }
    }
    else {
        $spnid = $Client_id
    }

    # Read Tenant
    $t = $iniContent[$Environment]["Tenant"]

    if ($Tenant -eq "") {
        if ($t -eq "" -or $null -eq $t) {
            $t = Read-Host -Prompt 'Tenant:'
        }
    }
    else {
        $t = $Tenant
    }

    if ($Client_secret -eq "") {
        $spnpwd = Read-Host -Prompt 'SPN Password:'
    }
    else {
        $spnpwd = $Client_secret
    }

    $Category1 = @{"Vault" = $v ; "Client_id" = $spnid ; "Tenant" = $t; "Subscription" = $sub }
    $iniContent[$Environment] = $Category1

    $iniContent | Out-IniFile -Force $filePath

    $Secret = ConvertTo-SecureString -String $sub -AsPlainText -Force
    $Secret_name = $Environment + "-subscription-id"
    Set-AzKeyVaultSecret -VaultName $v -Name $Secret_name -SecretValue $Secret

    $Secret = ConvertTo-SecureString -String $spnid -AsPlainText -Force
    $Secret_name = $Environment + "-client-id"
    Set-AzKeyVaultSecret -VaultName $v -Name $Secret_name -SecretValue $Secret


    $Secret = ConvertTo-SecureString -String $t -AsPlainText -Force
    $Secret_name = $Environment + "-tenant-id"
    Set-AzKeyVaultSecret -VaultName $v -Name $Secret_name -SecretValue $Secret

    $Secret = ConvertTo-SecureString -String $spnpwd -AsPlainText -Force
    $Secret_name = $Environment + "-client-secret"
    Set-AzKeyVaultSecret -VaultName $v -Name $Secret_name -SecretValue $Secret

    $Secret = ConvertTo-SecureString -String $sub -AsPlainText -Force
    $Secret_name = $Environment + "-subscription"
    Set-AzKeyVaultSecret -VaultName $v -Name $Secret_name -SecretValue $Secret

}


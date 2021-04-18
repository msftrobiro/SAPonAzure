function Remove-SAPSystem {
    <#
    .SYNOPSIS
        Removes a deployment

    .DESCRIPTION
        Removes a deployment

    .PARAMETER Parameterfile
        This is the parameter file for the system

    .PARAMETER Type
        This is the type of the system

    .EXAMPLE 

    #
    #
    # Import the module
    Import-Module "SAPDeploymentUtilities.psd1"
    Remove-System -Parameterfile .\PROD-WEEU-SAP00-X00.json -Type sap_system

    .EXAMPLE 

    #
    #
    # Import the module
    Import-Module "SAPDeploymentUtilities.psd1"
    Remove-System -Parameterfile .\PROD-WEEU-SAP_LIBRARY.json -Type sap_library

    
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
        #Parameter file
        [Parameter(Mandatory = $true)][string]$Parameterfile ,
        [Parameter(Mandatory = $true)][string]$Type
    )

    Write-Host -ForegroundColor green ""
    Write-Host -ForegroundColor green "Remove the" $Type

    $fInfo = Get-ItemProperty -Path $Parameterfile
    if (!$fInfo.Exists ) {
        Write-Error ("File " + $Parameterfile + " does not exist")
        return
    }

    $CachePath = (Join-Path -Path $Env:APPDATA -ChildPath "terraform.d\plugin-cache")
    if ( -not (Test-Path -Path $CachePath)) {
        New-Item -Path $CachePath -ItemType Directory
    }
    $env:TF_PLUGIN_CACHE_DIR = $CachePath

    Add-Content -Path "deployment.log" -Value ("Removing the: " + $Type)
    Add-Content -Path "deployment.log" -Value (Get-Date -Format "yyyy-MM-dd HH:mm")

    $mydocuments = [environment]::getfolderpath("mydocuments")
    $filePath = $mydocuments + "\sap_deployment_automation.ini"
    $iniContent = Get-IniContent -Path $filePath

    $jsonData = Get-Content -Path $Parameterfile | ConvertFrom-Json

    $Environment = $jsonData.infrastructure.environment
    $region = $jsonData.infrastructure.region
    $combined = $Environment + $region

    $deployer_tfstate_key = $iniContent[$combined]["Deployer"]
    $landscape_tfstate_key = $iniContent[$combined]["Landscape"]

    $tfstate_resource_id = $iniContent[$combined]["tfstate_resource_id"] 

    $repo = $iniContent["Common"]["repo"]
    $changed = $false

    if ($null -eq $repo -or "" -eq $repo) {
        $repo = Read-Host -Prompt "Please enter the subscription"
        $iniContent["Common"]["repo"] = $repo
        $changed = $true
    }

    if ($changed) {
        Out-IniFile -InputObject $iniContent -Path $filePath
    }
    
    $terraform_module_directory = Join-Path -Path $repo -ChildPath "\deploy\terraform\run\$Type"

    if ($Type -ne "sap_deployer") {
        $tfstate_parameter = " -var tfstate_resource_id=" + $tfstate_resource_id
    }

    if ($Type -eq "sap_landscape") {
        $tfstate_parameter = " -var tfstate_resource_id=" + $tfstate_resource_id
        if($deployer_tfstate_key.Length -gt 0) {
            $deployer_tfstate_key_parameter = " -var deployer_tfstate_key=" + $deployer_tfstate_key
        }
        else {
            $deployer_tfstate_key_parameter = " "
        }
    }

    if ($Type -eq "sap_library") {
        $tfstate_parameter = " -var tfstate_resource_id=" + $tfstate_resource_id
        $deployer_tfstate_key_parameter = " -var deployer_tfstate_key=" + $deployer_tfstate_key
    }

    if ($Type -eq "sap_system") {
        $tfstate_parameter = " -var tfstate_resource_id=" + $tfstate_resource_id
        if($deployer_tfstate_key.Length -gt 0) {
            $deployer_tfstate_key_parameter = " -var deployer_tfstate_key=" + $deployer_tfstate_key
        }
        else {
            $deployer_tfstate_key_parameter = " "
        }
        $landscape_tfstate_key_parameter = " -var landscape_tfstate_key=" + $landscape_tfstate_key
    }


    Write-Host -ForegroundColor green "Running destroy"
    $Command = " destroy -var-file " + $Parameterfile + $tfstate_parameter + $landscape_tfstate_key_parameter + $deployer_tfstate_key_parameter + " " + $terraform_module_directory

    $Cmd = "terraform -chdir=$terraform_module_directory $Command"
    Add-Content -Path "deployment.log" -Value $Cmd
    & ([ScriptBlock]::Create($Cmd))  
    if ($LASTEXITCODE -ne 0) {
        throw "Error executing command: $Cmd"
    }

    if ($Type -eq "sap_library") {
        $iniContent[$combined]["REMOTE_STATE_RG"] = "[DELETED]"
        $iniContent[$combined]["REMOTE_STATE_SA"] = "[DELETED]"
        $iniContent[$combined]["tfstate_resource_id"] = "[DELETED]"
        $iniContent[$combined]["kvsubscription"] = "[DELETED]"
        Out-IniFile -InputObject $iniContent -Path $filePath
    }

    if ($Type -eq "sap_landscape") {
        $iniContent[$combined]["Landscape"] = "[DELETED]"
        Out-IniFile -InputObject $iniContent -Path $filePath
    }
    if ($Type -eq "sap_deployer") {
        $iniContent[$combined]["Deployer"] = "[DELETED]"
        $iniContent[$combined]["kvsubscription"] = "[DELETED]"
    }

}
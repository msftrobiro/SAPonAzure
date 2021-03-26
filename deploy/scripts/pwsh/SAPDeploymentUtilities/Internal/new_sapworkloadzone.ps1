function New-SAPWorkloadZone {
    <#
    .SYNOPSIS
        Deploy a new SAP Workload Zone

    .DESCRIPTION
        Deploy a new SAP Workload Zone

    .PARAMETER Parameterfile
        This is the parameter file for the system

    .EXAMPLE 

    #
    #
    # Import the module
    Import-Module "SAPDeploymentUtilities.psd1"
    New-SAPWorkloadZone -Parameterfile .\PROD-WEEU-SAP00-infrastructure.json 

    
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
    [cmdletbinding(SupportsShouldProcess)]
    param(
        #Parameter file
        [Parameter(Mandatory = $true)][string]$Parameterfile 
    )

    Write-Host -ForegroundColor green ""
    $Type = "sap_landscape"
    Write-Host -ForegroundColor green "Deploying the" $Type
  
    Add-Content -Path "deployment.log" -Value ("Deploying the: " + $Type)
    Add-Content -Path "deployment.log" -Value (Get-Date -Format "yyyy-MM-dd HH:mm")
  
    $fInfo = Get-ItemProperty -Path $Parameterfile

    if ($false -eq $fInfo.Exists ) {
        Write-Error ("File " + $Parameterfile + " does not exist")
        return
    }

    $mydocuments = [environment]::getfolderpath("mydocuments")
    $fileINIPath = $mydocuments + "\sap_deployment_automation.ini"
    $iniContent = Get-IniContent -Path $fileINIPath

    $jsonData = Get-Content -Path $Parameterfile | ConvertFrom-Json

    $Environment = $jsonData.infrastructure.environment
    $region = $jsonData.infrastructure.region
    $combined = $Environment + $region

    $changed = $false

    if ($null -eq $iniContent["Common"]) {
        $repo = Read-Host -Prompt "Please enter path to the repo"
        $Category1 = @{"repo" = $repo }
        $iniContent += @{"Common" = $Category1 }
        $changed = $true
    }
    else {
        $repo = $iniContent["Common"]["repo"].Trim()
        if ($null -eq $repo -or "" -eq $repo) {
            $repo = Read-Host -Prompt "Please enter path to the repo"
            $iniContent["Common"]["repo"] = $repo
            $changed = $true
        }

    }

    if ($changed) {
        Out-IniFile -InputObject $iniContent -Path $fileINIPath
    }


    $changed = $false

    $landscape_tfstate_key = $fInfo.Name.replace(".json", ".terraform.tfstate")

    if ($null -eq $iniContent[$combined]) {
        Write-Error "The Terraform state information is not available"

        $saName = Read-Host -Prompt "Please specify the storage account name for the terraform storage account"
        $rID = Get-AzResource -Name $saName
        $rgName = $rID.ResourceGroupName

        $tfstate_resource_id = $rID.ResourceId

        $Category1 = @{"REMOTE_STATE_RG" = $rgName; "REMOTE_STATE_SA" = $saName; "tfstate_resource_id" = $tfstate_resource_id ; "Landscape" = $landscape_tfstate_key }
        $iniContent += @{$combined = $Category1 }
        if ($Type -eq "sap_landscape") {
            $iniContent[$combined].Landscape = $landscapeKey
        }
        Out-IniFile -InputObject $iniContent -Path $filePath
        $iniContent = Get-IniContent -Path $filePath
    }
    else {
        $deployer_tfstate_key = $iniContent[$combined]["Deployer"].Trim()
    }

    # Subscription
    $sub = $iniContent[$combined]["subscription"].Trim() 


    if ($null -eq $sub -or "" -eq $sub) {
        $sub = Read-Host -Prompt "Please enter the subscription for the deployment"
        $iniContent[$combined]["subscription"] = $sub.Trim() 
        $changed = $true

        $Command = " account set --sub " + $sub
        $Cmd = "az $Command"
        & ([ScriptBlock]::Create($Cmd)) 
        if ($LASTEXITCODE -ne 0) {
            throw "Error executing command: $Cmd"
        }
    }
    else {
        $Command = " account set --sub " + $sub
        $Cmd = "az $Command"
        & ([ScriptBlock]::Create($Cmd)) 
        if ($LASTEXITCODE -ne 0) {
            throw "Error executing command: $Cmd"
        }
    }


    if ($changed) {
        Out-IniFile -InputObject $iniContent -Path $fileINIPath
    }

    $ans = Read-Host -Prompt "Do you want to enter the Workload SPN secrets Y/N?"
    if ("Y" -eq $ans) {
        $vault = $iniContent[$combined]["Vault"]

        if (($null -eq $vault ) -or ("" -eq $vault)) {
            $vault = Read-Host -Prompt "Please enter the vault name"
            $iniContent[$combined]["Vault"] = $vault 
            Out-IniFile -InputObject $iniContent -Path $fileINIPath
    
        }
        try {
            Set-SAPSPNSecrets -Region $region -Environment $Environment -VaultName $vault -Workload $true
            $iniContent = Get-IniContent -Path $fileINIPath
        }
        catch {
            return
        }
    }

    $rgName = $iniContent[$combined]["REMOTE_STATE_RG"].Trim() 
    $saName = $iniContent[$combined]["REMOTE_STATE_SA"].Trim() 
    $tfstate_resource_id = $iniContent[$combined]["tfstate_resource_id"].Trim()

    $terraform_module_directory = Join-Path -Path $repo -ChildPath "\deploy\terraform\run\$Type"

    Write-Host -ForegroundColor green "Initializing Terraform"

    $Command = " init -upgrade=true -backend-config ""subscription_id=$sub"" -backend-config ""resource_group_name=$rgName"" -backend-config ""storage_account_name=$saName"" -backend-config ""container_name=tfstate"" -backend-config ""key=$envkey"" " + $terraform_module_directory

    if (Test-Path ".terraform" -PathType Container) {

        $jsonData = Get-Content -Path .\.terraform\terraform.tfstate | ConvertFrom-Json

        if ("azurerm" -eq $jsonData.backend.type) {
            $Command = " init -upgrade=true"

            $ans = Read-Host -Prompt ".terraform already exists, do you want to continue Y/N?"
            if ("Y" -ne $ans) {
                return
            }
        }
    } 

    $Cmd = "terraform $Command"
    & ([ScriptBlock]::Create($Cmd)) 
    if ($LASTEXITCODE -ne 0) {
        throw "Error executing command: $Cmd"
    }

    $tfstate_parameter = " -var tfstate_resource_id=" + $tfstate_resource_id
    $deployer_tfstate_key_parameter = " -var deployer_tfstate_key=" + $deployer_tfstate_key

    New-Item -Path . -Name "backend.tf" -ItemType "file" -Value "terraform {`n  backend ""azurerm"" {}`n}" -Force

    $Command = " output automation_version"

    $Cmd = "terraform $Command"
    Add-Content -Path "deployment.log" -Value $Cmd

    $versionLabel = & ([ScriptBlock]::Create($Cmd)) | Out-String 

    Write-Host $versionLabel
    if ("" -eq $versionLabel) {
        Write-Host ""
        Write-Host -ForegroundColor red "The environment was deployed using an older version of the Terrafrom templates"
        Write-Host ""
        Write-Host -ForegroundColor red "!!! Risk for Data loss !!!"
        Write-Host ""
        Write-Host -ForegroundColor red "Please inspect the output of Terraform plan carefully before proceeding" 
        Write-Host ""
        if ($PSCmdlet.ShouldProcess($Parameterfile)) {
            $ans = Read-Host -Prompt "Do you want to continue Y/N?"
            if ("Y" -eq $ans) {
    
            }
            else {
                return 
            }
        }
    }
    else {
        Write-Host ""
        Write-Host -ForegroundColor green "The environment was deployed using the $versionLabel version of the Terrafrom templates"
        Write-Host ""
        Write-Host ""
    }

    Write-Host -ForegroundColor green "Running plan, please wait"
    $Command = " plan -var-file " + $Parameterfile + $tfstate_parameter + $landscape_tfstate_key_parameter + $deployer_tfstate_key_parameter + " " + $terraform_module_directory

    $Cmd = "terraform $Command"
    Add-Content -Path "deployment.log" -Value $Cmd
    $planResults = & ([ScriptBlock]::Create($Cmd)) | Out-String 
    
    if ($LASTEXITCODE -ne 0) {
        throw "Error executing command: $Cmd"
    }

    $planResultsPlain = $planResults -replace '\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]', ''

    if ( $planResultsPlain.Contains('Infrastructure is up-to-date')) {
        Write-Host ""
        Write-Host -ForegroundColor Green "Infrastructure is up to date"
        Write-Host ""
        return;
    }

    Write-Host $planResults
    if (-not $planResultsPlain.Contains('0 to change, 0 to destroy') ) {
        Write-Host ""
        Write-Host -ForegroundColor red "!!! Risk for Data loss !!!"
        Write-Host ""
        Write-Host -ForegroundColor red "Please inspect the output of Terraform plan carefully before proceeding" 
        Write-Host ""
        if ($PSCmdlet.ShouldProcess($Parameterfile)) {
            $ans = Read-Host -Prompt "Do you want to continue Y/N?"
            if ("Y" -ne $ans) {
                return 
            }
        }
    }

    if ($PSCmdlet.ShouldProcess($Parameterfile)) {
        Write-Host -ForegroundColor green "Running apply"
        $Command = " apply -var-file " + $Parameterfile + $tfstate_parameter + $landscape_tfstate_key_parameter + $deployer_tfstate_key_parameter + " " + $terraform_module_directory
        Add-Content -Path "deployment.log" -Value $Cmd

        $Cmd = "terraform $Command"
        & ([ScriptBlock]::Create($Cmd))  
        if ($LASTEXITCODE -ne 0) {
            throw "Error executing command: $Cmd"
        }
    }
    if (Test-Path ".\backend.tf" -PathType Leaf) {
        Remove-Item -Path ".\backend.tf"  -Force 
    }

}
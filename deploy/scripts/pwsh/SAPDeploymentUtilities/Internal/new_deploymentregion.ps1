function New-SAPAutomationRegion {
    <#
    .SYNOPSIS
        Deploys a new SAP Environment (Deployer, Library and Workload VNet)

    .DESCRIPTION
        Deploys a new SAP Environment (Deployer, Library and Workload VNet)

    .PARAMETER DeployerParameterfile
        This is the parameter file for the Deployer

    .PARAMETER LibraryParameterfile
        This is the parameter file for the library

    .EXAMPLE 

    #
    #
    # Import the module
    Import-Module "SAPDeploymentUtilities.psd1"
     New-SAPAutomationRegion -DeployerParameterfile .\DEPLOYER\PROD-WEEU-DEP00-INFRASTRUCTURE\PROD-WEEU-DEP00-INFRASTRUCTURE.json \
     -LibraryParameterfile .\LIBRARY\PROD-WEEU-SAP_LIBRARY\PROD-WEEU-SAP_LIBRARY.json \

    
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
        [Parameter(Mandatory = $true)][string]$DeployerParameterfile,
        [Parameter(Mandatory = $true)][string]$LibraryParameterfile,
        [Parameter(Mandatory = $false)][Switch]$Force
    )

    Write-Host -ForegroundColor green ""
    Write-Host -ForegroundColor green "Preparing the azure region for the SAP automation"

    $step = 0

    $curDir = Get-Location 
    [IO.DirectoryInfo] $dirInfo = $curDir.ToString()

    $fileDir = $dirInfo.ToString() + $DeployerParameterfile
    [IO.FileInfo] $fInfo = $fileDir

    $DeployerRelativePath = "..\..\" + $fInfo.Directory.FullName.Replace($dirInfo.ToString() + "\", "")

    $jsonData = Get-Content -Path $DeployerParameterfile | ConvertFrom-Json

    $Environment = $jsonData.infrastructure.environment
    $region = $jsonData.infrastructure.region
    $combined = $Environment + $region

    $mydocuments = [environment]::getfolderpath("mydocuments")
    $filePath = $mydocuments + "\sap_deployment_automation.ini"

    if ( -not (Test-Path -Path $FilePath)) {
        New-Item -Path $mydocuments -Name "sap_deployment_automation.ini" -ItemType "file" -Value "[Common]`nrepo=`nsubscription=`n[$region]`nDeployer=`nLandscape=`n[$Environment]`nDeployer=`n[$combined]`nDeployer=`nSubscription=" -Force
    }

    $iniContent = Get-IniContent -Path $filePath

    $key = $fInfo.Name.replace(".json", ".terraform.tfstate")
    
    try {
        if ($null -ne $iniContent[$region] ) {
            $iniContent[$region]["Deployer"] = $key
        }
        else {
            $Category1 = @{"Deployer" = $key }
            $iniContent += @{$region = $Category1 }
            Out-IniFile -InputObject $iniContent -Path $filePath                    
        }
                
    }
    catch {
        
    }

    if ($true -eq $Force) {
        $iniContent.Remove($combined)
        Out-IniFile -InputObject $iniContent -Path $fileINIPath
        $iniContent = Get-IniContent -Path $fileINIPath
    }

    try {
        if ($null -ne $iniContent[$combined] ) {
            $iniContent[$combined]["Deployer"] = $key
        }
        else {
            $Category1 = @{"Deployer" = $key }
            $iniContent += @{$combined = $Category1 }
            Out-IniFile -InputObject $iniContent -Path $filePath                    
        }
                
    }
    catch {
        
    }

    if ($null -ne $iniContent[$combined]["step"]) {
        $step = $iniContent[$combined]["step"]
    }
    else {
        $step = 0
        $iniContent[$combined]["step"] = $step
    }

    $ctx = Get-AzContext
    if ($null -eq $ctx) {
        Connect-AzAccount
    }
 
    $errors_occurred = $false

    if (0 -eq $step) {
        Set-Location -Path $fInfo.Directory.FullName
        if ($true -eq $Force) {
            Remove-Item ".terraform" -ErrorAction SilentlyContinue -Recurse
            Remove-Item "terraform.tfstate" -ErrorAction SilentlyContinue
            Remove-Item "terraform.tfstate.backup" -ErrorAction SilentlyContinue
        }

        try {
            New-SAPDeployer -Parameterfile $fInfo.Name 
            $step = 1
            $iniContent[$combined]["step"] = $step
            Out-IniFile -InputObject $iniContent -Path $filePath

        }
        catch {
            $errors_occurred = $true
        }
        Set-Location -Path $curDir
    }

    if ($errors_occurred) {
        return
    }

    # Re-read ini file
    $iniContent = Get-IniContent -Path $filePath

    if (1 -eq $step) {

        $ans = Read-Host -Prompt "Do you want to enter the SPN secrets Y/N?"
        if ("Y" -eq $ans) {
            $vault = ""
            if ($null -ne $iniContent[$combined] ) {
                $vault = $iniContent[$combined]["Vault"]
            }

            if (($null -eq $vault ) -or ("" -eq $vault)) {
                $vault = Read-Host -Prompt "Please enter the vault name"
                $iniContent[$combined]["Vault"] = $vault 
                Out-IniFile -InputObject $iniContent -Path $filePath
    
            }
            try {
                Set-SAPSPNSecrets -Region $region -Environment $Environment -VaultName $vault  -Workload $false
                $step = 2
                $iniContent[$combined]["step"] = $step
                Out-IniFile -InputObject $iniContent -Path $filePath
    
            }
            catch {
                $errors_occurred = $true
            }
        }
    }

    $fileDir = $dirInfo.ToString() + $LibraryParameterfile
    [IO.FileInfo] $fInfo = $fileDir
    if (2 -eq $step) {
        Set-Location -Path $fInfo.Directory.FullName
        if ($true -eq $Force) {
            Remove-Item ".terraform" -ErrorAction SilentlyContinue -Recurse
            Remove-Item "terraform.tfstate" -ErrorAction SilentlyContinue
            Remove-Item "terraform.tfstate.backup" -ErrorAction SilentlyContinue

        }

        try {
            New-SAPLibrary -Parameterfile $fInfo.Name -DeployerFolderRelativePath $DeployerRelativePath
            $step = 3
            $iniContent[$combined]["step"] = $step
            Out-IniFile -InputObject $iniContent -Path $filePath
        }
        catch {
            $errors_occurred = $true
        }

        Set-Location -Path $curDir
    }
    if ($errors_occurred) {
        return
    }

    $fileDir = $dirInfo.ToString() + $DeployerParameterfile

    [IO.FileInfo] $fInfo = $fileDir
    if (3 -eq $step) {
        Write-Host "3"
        Set-Location -Path $fInfo.Directory.FullName
        try {
            New-SAPSystem -Parameterfile $fInfo.Name -Type sap_deployer
            $step = 4
            $iniContent[$combined]["step"] = $step
            Out-IniFile -InputObject $iniContent -Path $filePath

        }
        catch {
            Write-Error $_
            $errors_occurred = $true
        }

        Set-Location -Path $curDir
    }
    if ($errors_occurred) {
        return
    }

    $fileDir = $dirInfo.ToString() + $LibraryParameterfile
    [IO.FileInfo] $fInfo = $fileDir
    if (4 -eq $step) {
        Set-Location -Path $fInfo.Directory.FullName
        try {
            New-SAPSystem -Parameterfile $fInfo.Name -Type sap_library
            $step = 5
            $iniContent[$combined]["step"] = $step
            Out-IniFile -InputObject $iniContent -Path $filePath

        }
        catch {
            $errors_occurred = $true
        }

        Set-Location -Path $curDir
    }
    if ($errors_occurred) {
        return
    }

}
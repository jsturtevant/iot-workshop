#modified from https://github.com/Azure-Samples/MyDriving MIT license 

#Requires -Module AzureRM.Resources
Param(
   [string] [Parameter(Mandatory=$true)] $ResourceGroupLocation,
   [string] [Parameter(Mandatory=$true)] $ResourceGroupName
)

# Variables
[string] $TemplateFile = '..\ARM\scenario_complete.json'
[string] $ParametersFile = '..\ARM\scenario_complete.params.json'

[string] $DeploymentName = ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm'))

$deployment1 = $null

Import-Module Azure -ErrorAction Stop

$TemplateFile = [System.IO.Path]::Combine($PSScriptRoot, $TemplateFile)
$ParametersFile = [System.IO.Path]::Combine($PSScriptRoot, $ParametersFile)

# verify if user is logged in by querying his subscriptions.
# if none is found assume she is not
Write-Output ""
Write-Output "**************************************************************************************************"
Write-Output "* Retrieving Azure subscription information..."
Write-Output "**************************************************************************************************"
try
{
	$Subscriptions = Get-AzureRmSubscription
	if (!($Subscriptions)) {
		Login-AzureRmAccount 
	}
}
catch
{
    Login-AzureRmAccount 
}

# fail if we still can retrieve any subscription
$Subscriptions = Get-AzureRmSubscription
if (!($Subscriptions)) {
    Write-Host "Login failed or there are no subscriptions available with your account." -ForegroundColor Red
    Write-Host "Please logout using the command azure Remove-AzureAccount -Name [username] and try again." -ForegroundColor Red
    exit
}

$subscription

# if the user has more than one subscriptions force the user to select one
if ($Subscriptions.Length -gt 1) {
    $i = 1
    $Subscriptions | % { Write-Host "$i) $($_.SubscriptionName)"; $i++ }

    while($true)
    {
        $input = Read-Host "Please choose which subscription to use (1-$($Subscriptions.Length))"
        $intInput = -1

        if ([int]::TryParse($input, [ref]$intInput) -and ($intInput -ge 1 -and $intInput -le $Subscriptions.Length)) {
            Select-AzureRmSubscription -SubscriptionId $($Subscriptions.Get($intInput-1).SubscriptionId)
            $subscription = $Subscriptions.Get($intInput-1)
            break;
        }
    }
} else {
    $subscription = $Subscriptions
}


# Create or update the resource group using the specified template file and template parameters file
Write-Output ""
Write-Output "**************************************************************************************************"
Write-Output "* Creating the resource group..."
Write-Output "**************************************************************************************************"
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force -ErrorAction Stop 

# Create required services
Write-Output ""
Write-Output "**************************************************************************************************"
Write-Output "* Deploying the resources in the ARM template. This operation may take several minutes..."
Write-Output "**************************************************************************************************"

Write-Warning "If asked for SQL Server password use strong password as defined here: https://msdn.microsoft.com/library/ms161962.aspx"
Write-Warning "Is at least 8 characters long and combines letters, numbers, and symbol characters within the password"

$deployment1 = New-AzureRmResourceGroupDeployment -Name "$DeploymentName-0" `
													-ResourceGroupName $ResourceGroupName `
													-TemplateFile $TemplateFile `
													-TemplateParameterFile $ParametersFile `
													-Force -Verbose

if ($deployment1.ProvisioningState -ne "Succeeded") {
	Write-Warning "Skipping the storage and database initialization..."
	Write-Error "At least one resource could not be provisioned successfully. Review the output above to correct any errors and then run the deployment script again."
	exit 2
}

Write-Output ""

Write-Output "The deployment is complete!"

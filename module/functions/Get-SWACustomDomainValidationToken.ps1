# <copyright file="Get-SWACustomDomainValidationToken.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
    Retrieves the validation token for a custom domain configured on an Azure Static Web App.

.DESCRIPTION
    This function polls an Azure Static Web App to retrieve the validation token for a specified custom domain.
    The validation token is required to prove domain ownership when setting up custom domains.
    
    The function implements a retry mechanism with configurable polling intervals and maximum attempts,
    as the validation token may not be immediately available after domain configuration.

.PARAMETER ResourceGroupName
    The name of the Azure resource group containing the Static Web App.

.PARAMETER Name
    The name of the Azure Static Web App.

.PARAMETER Domain
    The custom domain name for which to retrieve the validation token (e.g., "www.example.com").

.PARAMETER PollingIntervalSeconds
    The number of seconds to wait between polling attempts when the validation token is not yet available.
    Default value is 15 seconds.

.PARAMETER MaxPollingAttempts
    The maximum number of polling attempts before giving up and throwing an error.
    Default value is 8 attempts.

.OUTPUTS
    System.String
    Returns the validation token as a string if found, or $null if no custom domain is configured.

.EXAMPLE
    Get-SWACustomDomainValidationToken -ResourceGroupName "rg-myapp" -Name "myapp-swa" -Domain "www.myapp.com"
    
    Retrieves the validation token for the domain "www.myapp.com" configured on the Static Web App "myapp-swa"
    in resource group "rg-myapp" using default polling settings.

.EXAMPLE
    Get-SWACustomDomainValidationToken -ResourceGroupName "rg-myapp" -Name "myapp-swa" -Domain "api.myapp.com" -PollingIntervalSeconds 30 -MaxPollingAttempts 5
    
    Retrieves the validation token with custom polling settings: 30-second intervals and maximum 5 attempts.

.NOTES
    - Requires the Az.Websites PowerShell module to be installed and imported
    - The user must be authenticated to Azure with appropriate permissions to read Static Web App configurations
    - If the custom domain is not configured on the Static Web App, the function returns $null
    - If the validation token cannot be retrieved within the specified attempts, an exception is thrown

.LINK
    https://docs.microsoft.com/en-us/azure/static-web-apps/custom-domain

.LINK
    Get-AzStaticWebAppCustomDomain
#>
function Get-SWACustomDomainValidationToken {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Domain,

        [Parameter()]
        [ValidateRange(1, 300)]
        [int] $PollingIntervalSeconds = 15,

        [Parameter()]
        [ValidateRange(1, 50)]
        [int] $MaxPollingAttempts = 8
    )

    # Initialize attempt counter
    $currentAttempt = 0
    
    Write-Verbose "Starting to poll for custom domain validation token for domain '$Domain' on Static Web App '$Name'"
    
    while ($currentAttempt -lt $MaxPollingAttempts) {
        $currentAttempt++
        Write-Verbose "Polling attempt $currentAttempt of $MaxPollingAttempts"
        
        try {
            # Retrieve the custom domain configuration from Azure
            $customDomain = Get-AzStaticWebAppCustomDomain `
                                        -ResourceGroupName $ResourceGroupName `
                                        -Name $Name `
                                        -Domain $Domain `
                                        -ErrorAction SilentlyContinue

            if ($customDomain) {
                # Custom domain exists, check if validation token is available
                if ([string]::IsNullOrEmpty($customDomain.ValidationToken)) {
                    Write-Verbose "Custom domain validation token for site '$Name' and domain '$Domain' is not yet available"
                    
                    if ($currentAttempt -lt $MaxPollingAttempts) {
                        Write-Verbose "Will re-check in $PollingIntervalSeconds seconds (attempt $currentAttempt of $MaxPollingAttempts)"
                        Start-Sleep -Seconds $PollingIntervalSeconds
                    }
                }
                else {
                    Write-Verbose "Custom domain validation token for site '$Name' and domain '$Domain' found on attempt $currentAttempt"
                    return $customDomain.ValidationToken
                }
            }
            else {
                # Custom domain not found - this means it's not configured
                Write-Information "The site '$Name' is not configured with the custom domain '$Domain'" -InformationAction Continue
                return $null
            }
        }
        catch {
            Write-Warning "Error occurred while retrieving custom domain information on attempt $currentAttempt`: $($_.Exception.Message)"
            
            if ($currentAttempt -lt $MaxPollingAttempts) {
                Write-Verbose "Will retry in $PollingIntervalSeconds seconds"
                Start-Sleep -Seconds $PollingIntervalSeconds
            }
        }
    }

    # If we reach here, all attempts have been exhausted
    $errorMessage = "The site '$Name' is configured with the custom domain '$Domain', but the validation token could not be retrieved after $currentAttempt attempts"
    throw $errorMessage
}
        
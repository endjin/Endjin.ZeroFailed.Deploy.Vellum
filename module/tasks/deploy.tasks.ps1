# <copyright file="deploy.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: Configures the required ARM deployment using the ZeroFailed.Deploy.Azure extension conventions
task SetupVellumArmDeployment -Before ProvisionCore readConfiguration,{

    # Populate ARM deployment configuration required by ZeroFailed.Deploy.Azure extension
    $script:RequiredArmDeployments = @(
        @{
            templatePath       = "$PSScriptRoot/../bicep/main.bicep"
            resourceGroupName  = { $deploymentConfig.resourceGroupName }
            location           = { $deploymentConfig.azureLocation }
            # ZeroFailed uses a convention whereby configuration settings are assumed to match ARM deployment parameters.
            # This value overrides this behaviour by removing any config settings not required for ARM deployment,
            # or with an empty value so the ARM parameter defaults can be used.
            configKeysToIgnore = @(
                "RequiredConfiguration"
                "azureLocation"
                "azureSubscriptionId"
                "azureTenantId"
                "resourceGroupName"
            )
        }
    )
}

# Synopsis: Configures an Azure Static Web App with a custom domain hosted on Azure DNS
task ConfigureCustomDomainWithAzureDns -After ProvisionCore -If { $deploymentConfig.customDomain -and $deploymentConfig.useAzureDns} {

    # Configuring custom domains via Bicep/ARM requires that the DNS TXT records already exist, otherwise the
    # deployment will timeout as it waits to validate the custom domain.
    #
    # This task will take care of enabling the custom domain and registering a the relevant DNS TXT record
    # so it can be validated.
    #
    # NOTE: This script assumes that the domain name registration is already delegated to Azure DNS for resolution.
    $site = Get-AzStaticWebApp -ResourceGroupName $deploymentConfig.resourceGroupName `
                               -Name $deploymentConfig.siteName `
                               -ErrorAction Ignore

    if (!$site) {
        throw "The Azure Static Web App not found: [ResourceGroup=$($deploymentConfig.resourceGroupName)] [Name=$($deploymentConfig.siteName)]"
    }

    # Call SWA REST API directly since the 'Get-AzStaticWebAppCustomDomain' cmdlet does not surface the custom domain's status details
    $customDomainResp = Invoke-AzRestMethod -Uri "https://management.azure.com$($site.Id)/customDomains/$($deploymentConfig.customDomain)?api-version=2024-11-01"
    
    # Handle when the custom domain has not yet been setup
    if ($customDomainResp.StatusCode -eq 404) {
        Write-Build White "Adding custom domain '$($deploymentConfig.customDomain)' for the Azure Static Web App '$($deploymentConfig.siteName)'"
        $newCustomDomainResp = New-AzStaticWebAppCustomDomain `
                                    -ResourceGroupName $deploymentConfig.resourceGroupName `
                                    -Name $deploymentConfig.siteName `
                                    -Domain $deploymentConfig.customDomain `
                                    -ValidationMethod 'dns-txt-token' `
                                    -NoWait

        # Re-read the custom domain details which should now be setup
        Start-Sleep -Seconds 5
        $customDomainResp = Invoke-AzRestMethod -Uri "https://management.azure.com$($site.Id)/customDomains/$($deploymentConfig.customDomain)?api-version=2024-11-01"
    }

    if ($customDomainResp.StatusCode -ge 400) {
        throw "Error or unexpected response whilst querying the Static Web App Custom Domain [StatusCode=$($customDomainResp.StatusCode)] [Code=$($customDomainResp.Code)] [Message=$($customDomainResp.Message)]"
    }
    else {
        # Custom domain exists, extracts its properties
        $customDomain = $customDomainResp |
                            Select-Object -ExpandProperty Content |
                            ConvertFrom-Json -Depth 100 |
                            Select-Object -ExpandProperty properties |
                            ConvertFrom-Json -Depth 100

        # If the domain is already fully-configured then there is nothing further to do
        if ($customDomain.status -eq 'Ready') {
            Write-Build Green "✅ The custom domain is in a ready state"
            return
        }
    }

    # If we get this far then the domain is not yet fully configured, so we need to check
    # that the DNS is setup with the correct validation token
    $validationToken = Get-SWACustomDomainValidationToken `
                            -ResourceGroupName $deploymentConfig.resourceGroupName `
                            -Name $deploymentConfig.siteName `
                            -Domain $deploymentConfig.customDomain `
                            -PollingIntervalSeconds 15 `
                            -MaxPollingAttempts 8

    # Ensure that a DNS TXT record is configured with the validation token
    #
    # NOTE: The Bicep deployment is responsible for deploying the DNS Zone and an ALIAS record that points to the SWA resource.
    $existingDnsZone = Get-AzDnsZone -ResourceGroupName $deploymentConfig.resourceGroupName -Name $deploymentConfig.customDomain
    if ($existingDnsZone) {
        $existingDnsTxtRecordSet = $existingDnsZone |
                                        Get-AzDnsRecordSet |
                                        Where-Object { $_.Name -eq '@' -and $_.RecordType -eq 'TXT' }
                                        
        if (!$existingDnsTxtRecordSet) {
            # No TXT record exists in the DNS Zone
            Write-Build White "Creating DNS 'TXT' recordset"
            $existingDnsTxtRecordSet = New-AzDnsRecordSet `
                                            -ZoneName $deploymentConfig.customDomain `
                                            -ResourceGroupName $deploymentConfig.resourceGroupName `
                                            -Name '@' `
                                            -RecordType 'TXT' `
                                            -Ttl 3600 `
                                            -DnsRecords @()
        }
        
        $existingDnsTxtRecord = $existingDnsTxtRecordSet | Select-Object -ExpandProperty Records

        # Debugging issue
        $existingCustomDomain | Out-String | Write-Verbose -verbose:$true
        $existingDnsTxtRecord | Out-String | Write-Verbose -verbose:$true

        if ($existingDnsTxtRecord -and $existingDnsTxtRecord.Value -is [string] -and $existingDnsTxtRecord.Value -eq $validationToken) {
            # The existing TXT record contains a single & value value
            Write-Build Green "✅ Domain validation DNS 'TXT' record already configured with current validation token"
        }
        elseif (![string]::IsNullOrEmpty($validationToken)) {
            # We don't have a suitable TXT record

            if ($existingDnsTxtRecord) {
                # The TXT record exists but contains an old value(s) we need to purge
                Write-Build White "Removing existing domain validation DNS 'TXT' record with incorrect value"
                $existingDnsTxtRecord | Remove-AzDnsRecordConfig -RecordSet $existingDnsTxtRecordSet | Out-String | Write-Verbose
            }

            # Now we can setup the required TXT record
            Write-Build Green "✅ Adding domain validation DNS 'TXT' record with current validation token"
            Add-AzDnsRecordConfig -RecordSet $existingDnsTxtRecordSet -Value $validationToken | Out-String | Write-Verbose
            Set-AzDnsRecordSet -RecordSet $existingDnsTxtRecordSet | Out-String | Write-Verbose
        }
    }
    else {
        Write-Warning "Skipping custom domain validation steps; unable to find Azure DNS Zone for '$($deploymentConfig.customDomain)' [ResourceGroup=$($deploymentConfig.resourceGroupName)]"
    }
}

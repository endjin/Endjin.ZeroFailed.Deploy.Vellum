# <copyright file="deploy.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# # Populate ARM deployment configuration required by ZeroFailed.Deploy.Azure extension
# $script:RequiredArmDeployments = @(
#     @{
#         templatePath       = "$PSScriptRoot/bicep/main.bicep"
#         resourceGroupName  = { $deploymentConfig.resourceGroupName }
#         location           = { $deploymentConfig.azureLocation }
#         # ZeroFailed uses a convention whereby configuration settings are assumed to match ARM deployment parameters.
#         # This value overrides this behaviour by removing any config settings not required for ARM deployment,
#         # or with an empty value so the ARM parameter defaults can be used.
#         configKeysToIgnore = @(
#             "RequiredConfiguration"
#             "azureLocation"
#             "resourceGroupName"
#         )
#     }
# )
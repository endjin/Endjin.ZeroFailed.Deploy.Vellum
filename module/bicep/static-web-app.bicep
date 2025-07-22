// <copyright file="static-web-app.bicep" company="Endjin Limited">
// Copyright (c) Endjin Limited. All rights reserved.
// </copyright>
targetScope = 'resourceGroup'

param appLocation string
param location string
param siteName string
param customDomain string = ''
param dnsResourceGroupName string
param useAzureDns bool
@secure()
param previewSitesPassword string = ''

param repositoryBranch string = 'main'
param allowConfigFileUpdates bool = true
@allowed([
  'Free'
  'Standard'
])
param skuName string = 'Free'
@allowed([
  'Enabled'
  'Disabled'
])
param stagingEnvironmentPolicy string = 'Enabled'
param repositoryUrl string

resource swa 'Microsoft.Web/staticSites@2024-11-01' = {
  name: siteName
  location: location
  sku: {
    name: skuName
  }
  properties: {
    // repositoryToken: repositoryToken
    repositoryUrl: repositoryUrl
    branch: repositoryBranch
    stagingEnvironmentPolicy: stagingEnvironmentPolicy
    allowConfigFileUpdates: allowConfigFileUpdates
    buildProperties: {
      appLocation: appLocation
      skipGithubActionWorkflowGeneration: true
    }
  }
}

// Create a Azure public DNS zone for the custom domain
module dns './dns.bicep' = if (!empty(customDomain) && useAzureDns) {
  name: 'dnsDeploy'
  scope: resourceGroup(dnsResourceGroupName)
  params: {
    domainName: customDomain
    siteResourceId: swa.id
  }
}

// Undocumented feature for password-protecting access to preview sites
resource swa_config 'Microsoft.Web/staticSites/config@2024-11-01'= if (!empty(previewSitesPassword)) {
#disable-next-line BCP036
  name: 'basicAuth'
  parent: swa
  properties: {
    password: previewSitesPassword
    secretState: 'Password'
    applicableEnvironmentsMode: 'StagingEnvironments'
  }
}

output fqdn string = swa.properties.defaultHostname
output name string = swa.name

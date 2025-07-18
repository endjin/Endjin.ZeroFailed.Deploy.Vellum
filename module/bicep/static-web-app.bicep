param appLocation string
param location string
param siteName string
param customDomain string = ''

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

resource swa 'Microsoft.Web/staticSites@2022-03-01' = {
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

resource custom_domain 'Microsoft.Web/staticSites/customDomains@2022-03-01' = if (!empty(customDomain)) {
  name: empty(customDomain) ? 'unused' : customDomain
  parent: swa
  properties: {}
}

output fqdn string = swa.properties.defaultHostname

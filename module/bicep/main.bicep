targetScope = 'resourceGroup'


param appLocationInRepo string
param siteName string
param customDomain string = ''
param repositoryUrl string
param repositoryBranch string
@allowed([
  'Free'
  'Standard'
])
param staticWebAppSku string = 'Free'
param location string = resourceGroup().location


module swa './static-web-app.bicep' = {
  name: 'swaDeploy'
  params: {
    appLocation: appLocationInRepo
    location: location
    siteName: siteName
    repositoryUrl: repositoryUrl
    repositoryBranch: repositoryBranch
    skuName: staticWebAppSku
    customDomain: customDomain
  }
}


output fqdn string = swa.outputs.fqdn

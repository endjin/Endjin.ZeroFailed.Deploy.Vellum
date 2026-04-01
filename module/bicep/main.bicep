// <copyright file="main.bicep" company="Endjin Limited">
// Copyright (c) Endjin Limited. All rights reserved.
// </copyright>
targetScope = 'resourceGroup'

param apiLocationInRepo string = ''
param appLocationInRepo string
param siteName string
param customDomain string = ''
param useAzureDns bool = false
param repositoryUrl string
param repositoryBranch string
@allowed([
  'Free'
  'Standard'
])
param staticWebAppSku string = 'Free'
param location string = resourceGroup().location
param dnsResourceGroupName string = resourceGroup().name
param dnsResourceSubscriptionId string = subscription().subscriptionId
param enableEnterpriseEdge bool
@secure()
param previewSitesPassword string = ''

module swa './static-web-app.bicep' = {
  name: 'swaDeploy'
  params: {
    apiLocation: apiLocationInRepo
    appLocation: appLocationInRepo
    location: location
    siteName: siteName
    repositoryUrl: repositoryUrl
    repositoryBranch: repositoryBranch
    skuName: staticWebAppSku
    customDomain: customDomain
    useAzureDns: useAzureDns
    dnsResourceGroupName: dnsResourceGroupName
    dnsResourceSubscriptionId: dnsResourceSubscriptionId
    enableEnterpriseEdge: enableEnterpriseEdge
    previewSitesPassword: previewSitesPassword
  }
}

output fqdn string = swa.outputs.fqdn

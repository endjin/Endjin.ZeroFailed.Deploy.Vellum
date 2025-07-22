// <copyright file="main.bicep" company="Endjin Limited">
// Copyright (c) Endjin Limited. All rights reserved.
// </copyright>
targetScope = 'resourceGroup'

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
    useAzureDns: useAzureDns
    dnsResourceGroupName: dnsResourceGroupName
  }
}

output fqdn string = swa.outputs.fqdn

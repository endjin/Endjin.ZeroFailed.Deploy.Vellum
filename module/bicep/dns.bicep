// <copyright file="dns.bicep" company="Endjin Limited">
// Copyright (c) Endjin Limited. All rights reserved.
// </copyright>
targetScope = 'resourceGroup'

param domainName string
param siteResourceId string
// param siteValidationToken string
param location string = resourceGroup().location

resource dns_zone 'Microsoft.Network/dnsZones@2023-07-01-preview' = {
  name: domainName
  location: location
}

resource alias_record 'Microsoft.Network/dnszones/A@2023-07-01-preview' = {
  parent: dns_zone
  name: '@'
  properties: {
    TTL: 3600
    targetResource: {
      id: siteResourceId
    }
    trafficManagementProfile: {}
  }
}

// The required TXT record is handled outside the ARM deployment since
// the SWA resource will hang until the DNS record exists, but we don't know
// what the validation token is until the SWA resource deployment completes!

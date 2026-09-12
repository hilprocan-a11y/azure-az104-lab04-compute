targetScope = 'resourceGroup'

param location string
param adminUsername string = 'azureuser'
@secure()
param adminSshPublicKey string
var nginxConfig = '''
#cloud-config
package_update: true
packages:
  - nginx
runcmd:
  - |
    echo "<h1>Lab04 - $(hostname)</h1>" > /var/www/html/index.html
    systemctl enable --now nginx
'''

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-hn-az104-lab04'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-HTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-hn-az104-lab04'
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ '10.0.0.0/16' ] }
    subnets: [
      {
        name: 'subnet-default'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: { id: nsg.id }
        }
      }
    ]
  }
}

param vmName string = 'vm-hn-az104-lab04'
param vmSize string = 'Standard_B2pls_v2'

resource vmPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${vmName}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource vmNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${vmName}-nic'
  location: location
    dependsOn: [
    vnet
    loadBalancer
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: vmPublicIp.id
          }
          subnet: {
            id: resourceId(
              'Microsoft.Network/virtualNetworks/subnets',
              'vnet-hn-az104-lab04',
              'subnet-default'
            )
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-22_04-lts'
        sku: 'server-arm64'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      customData: base64(nginxConfig)
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminSshPublicKey
            }
          ]
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNic.id
        }
      ]
    }
  }
}

param vmssName string = 'vmss-hn-az104-lab04'
param vmssCapacity int = 1

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2024-07-01' = {
  name: vmssName
  location: location
    dependsOn: [
    vnet
    loadBalancer
  ]
  sku: {
    name: vmSize
    tier: 'Standard'
    capacity: vmssCapacity
  }
  properties: {
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      osProfile: {
        customData: base64(nginxConfig)
        computerNamePrefix: 'lab04'
        adminUsername: adminUsername
        linuxConfiguration: {
          disablePasswordAuthentication: true
          ssh: {
            publicKeys: [
              {
                path: '/home/${adminUsername}/.ssh/authorized_keys'
                keyData: adminSshPublicKey
              }
            ]
          }
        }
      }
      storageProfile: {
        imageReference: {
          publisher: 'Canonical'
          offer: 'ubuntu-22_04-lts'
          sku: 'server-arm64'
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'vmss-nic-config'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig1'
                  properties: {
                    subnet: {
                      id: resourceId(
                        'Microsoft.Network/virtualNetworks/subnets',
                        'vnet-hn-az104-lab04',
                        'subnet-default'
                      )
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: resourceId(
                          'Microsoft.Network/loadBalancers/backendAddressPools',
                          loadBalancerName,
                          'backendpool'
                        )
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}

param loadBalancerName string = 'lb-hn-az104-lab04'
param loadBalancerPublicIpName string = 'lb-hn-az104-lab04-pip'

resource loadBalancerPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: loadBalancerPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2024-05-01' = {
  name: loadBalancerName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontend'
        properties: {
          publicIPAddress: {
            id: loadBalancerPublicIp.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backendpool'
      }
    ]

          outboundRules: [
      {
        name: 'outboundInternet'
        properties: {
          protocol: 'All'
          allocatedOutboundPorts: 1024
          idleTimeoutInMinutes: 4
          backendAddressPool: {
            id: resourceId(
              'Microsoft.Network/loadBalancers/backendAddressPools',
              loadBalancerName,
              'backendpool'
            )
          }
          frontendIPConfigurations: [
            {
              id: resourceId(
                'Microsoft.Network/loadBalancers/frontendIPConfigurations',
                loadBalancerName,
                'frontend'
              )
            }
          ]
        }
      }
    ]
        probes: [
      {
        name: 'httpProbe'
        properties: {
          protocol: 'Http'
          port: 80
          requestPath: '/'
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'httpRule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId(
              'Microsoft.Network/loadBalancers/frontendIPConfigurations',
              loadBalancerName,
              'frontend'
            )
          }
          backendAddressPool: {
            id: resourceId(
              'Microsoft.Network/loadBalancers/backendAddressPools',
              loadBalancerName,
              'backendpool'
            )
          }
          probe: {
            id: resourceId(
              'Microsoft.Network/loadBalancers/probes',
              loadBalancerName,
              'httpProbe'
            )
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          disableOutboundSnat: true
          idleTimeoutInMinutes: 4
        }
      }
    ]
  }
}




param appServicePlanName string = 'plan-hn-az104-lab04'
param webAppName string = 'app-hn-az104-lab04'
param acrName string = 'acrhnlab04'
param aciName string = 'aci-hn-lab04-web'
param deployAci bool = false

resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: { name: 'F1', tier: 'Free' }
  properties: { reserved: true }
}

resource webApp 'Microsoft.Web/sites@2024-11-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|24-lts'
      appSettings: [{ name: 'APP_ENV', value: 'training' }]
    }
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: { name: 'Basic' }
  properties: { adminUserEnabled: false }
}

resource aciIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-hn-az104-lab04-aci'
  location: location
}

resource aciAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, aciIdentity.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    )
    principalId: aciIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource aci 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = if (deployAci) {
  name: aciName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aciIdentity.id}': {}
    }
  }
  dependsOn: [
    aciAcrPull
  ]
  properties: {
    imageRegistryCredentials: [
      {
        server: acr.properties.loginServer
        identity: aciIdentity.id
      }
    ]
    osType: 'Linux'
    restartPolicy: 'OnFailure'
    ipAddress: {
      type: 'Public'
      ports: [
        {
          protocol: 'TCP'
          port: 80
        }
      ]
    }
    containers: [{
      name: 'nginx'
      properties: {
        image: '${acr.properties.loginServer}/lab04-web:v1'
        ports: [
          {
            port: 80
          }
        ]
        resources: {
          requests: {
            cpu: 1
            memoryInGB: 1
          }
        }
      }
    }]
  }
}




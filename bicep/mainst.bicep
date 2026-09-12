targetScope = 'subscription'

param location string = 'centralus'
param computeResourceGroupName string = 'rg-hn-az104-lab04-compute'

@secure()
param adminSshPublicKey string

param deployAci bool = false

resource computeResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: computeResourceGroupName
  location: location
}

module compute './compute.bicep' = {
  name: 'lab04-compute'
  scope: computeResourceGroup
  params: {
    location: location
    adminSshPublicKey: adminSshPublicKey
    deployAci: deployAci
  }
}

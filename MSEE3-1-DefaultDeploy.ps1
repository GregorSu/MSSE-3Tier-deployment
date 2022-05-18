# Variable $MSEEEnvPrefix should contain trailing "-" it it would be contactenated as prefix to already definded final
# name of the resources in the environment
$MSEEEnvPrefix = "MSEEDEV"
$MSEEResourcesPrefix = "MSEE"
$Location = "eastus2"
$DeploymentName = "MSEEDEV-220108"

# Added next lines for Sandbox GregorSu environment 
$TenantRootGroupId = "a343d0df-132c-4f1a-b739-d1319eb013ae"
$PlatformSubscriptionId = "389a8786-8225-400e-9557-7802ca4093ff"
$Partner1SubscriptionId = "4be3677f-1aa8-4000-8654-060b9e9826c9"  
$MSEESecurityContactEmailAddress = "alerts@mseedev.microsoft.com"
$ConnectivityAddressPrefix = "10.10.0.0/16"

# OK - Deploy management groups...
New-AzManagementGroupDeployment -Name "$($DeploymentName)-Deploy-ManagementGroups" `
                                -ManagementGroupId $TenantRootGroupId `
                                -Location $Location `
                                -TemplateFile ".\MSEE-mgmtGroups.json" `
                                -topLevelManagementGroupPrefix $MSEEEnvPrefix `
                                -Verbose
                                
# OK - Deploy Policies...
New-AzManagementGroupDeployment -Name "$($DeploymentName)-Policies-MSEERoot" `
                                -ManagementGroupId $MSEEEnvPrefix `
                                -Location $Location `
                                -TemplateFile ".\MSEE-policies-TEMP.json" `
                                -topLevelManagementGroupPrefix $MSEEEnvPrefix `
                                -Verbose
                                 
# OK - Deploy policy initiative for preventing usage of public endpoint for Azure PaaS services
New-AzManagementGroupDeployment -Name "$($DeploymentName)-Policies-DenyPublicEndpoints" `
                                -ManagementGroupId $MSEEEnvPrefix `
                                -Location $Location `
                                -TemplateFile ".\MSEE-DENY-PublicEndpointsPolicySetDefinition.json" `
                                -Verbose

# OK - Deploying policy initiative for associating private DNS zones with private endpoints for Azure PaaS services
New-AzManagementGroupDeployment -Name "$($DeploymentName)-Policies-PrivateDNSEndpoints" `
                                -ManagementGroupId $MSEEEnvPrefix `
                                -Location $Location `
                                -TemplateFile ".\MSEE-DINE-PrivateDNSZonesPolicySetDefinition.json" `
                                -Verbose

# OK - Add dedicated subscription for Platform
New-AzManagementGroupDeployment -Name "$($DeploymentName)-Platform-AssignSubscription" `
                                -ManagementGroupId "$($MSEEEnvPrefix)-Platform" `
                                -Location $Location `
                                -TemplateFile ".\MSEE-subscriptionOrganization.json" `
                                -targetManagementGroupId "$($MSEEEnvPrefix)-Platform" `
                                -subscriptionId $PlatformSubscriptionId `
                                -Verbose

# OK - Add dedicated subscription for Partner1 
New-AzManagementGroupDeployment -Name "$($DeploymentName)-Partner1-AssignSubscription" `
                                -ManagementGroupId "$($MSEEEnvPrefix)-Partner1" `
                                -Location $Location `
                                -TemplateFile ".\MSEE-subscriptionOrganization.json" `
                                -targetManagementGroupId "$($MSEEEnvPrefix)-Partner1" `
                                -subscriptionId $Partner1SubscriptionId `
                                -Verbose

# OK - Deploy Log Analytics Workspace to the MSEE platform subscription
Select-AzSubscription -SubscriptionName $PlatformSubscriptionId
New-AzSubscriptionDeployment -Name "$($DeploymentName)-Deploy-LogAnalytics" `
                             -Location $Location `
                             -TemplateFile ".\MSEE-logAnalyticsWorkspace.json" `
                             -rgName "rg-plt-ue2-core-01" `
                             -workspaceName "opiw-plt-ue2-core-01" `
                             -workspaceRegion $Location `
                             -retentionInDays "90" `
                             -automationAccountName "aa-plt-eu2-core-01" `
                             -automationRegion $Location `
                             -Verbose

# OK - Deploy Log Analytics Solutions to the Log Analytics workspace in the MXDR platform subscription
# I've tested the Solutions, deployment works, but I am not sure if we actually need them all. Every solution in the JSON is enabled, but
# we can also disable some of them.
Select-AzSubscription -SubscriptionName $PlatformSubscriptionId
New-AzSubscriptionDeployment -Name "$($DeploymentName)-Deploy-LogAnalytics-Solutions" `
                             -Location $Location `
                             -TemplateFile ".\MSEE-logAnalyticsSolutions.json" `
                             -rgName "rg-plt-ue2-core-01" `
                             -workspaceName "opiw-plt-ue2-core-01" `
                             -workspaceRegion $Location `
                             -Verbose                             

# OK - Assign Azure Policy to enforce Log Analytics workspace on the MSEE PLATFORM Management group
New-AzManagementGroupDeployment -Name "$($DeploymentName)-PolicyAssignment-LogAnalyticsWorkspace" `
                                -Location $Location `
                                -TemplateFile ".\MSEE-DINE-LogAnalyticsPolicyAssignment.json" `
                                -retentionInDays "90" `
                                -rgName "rg-plt-ue2-core-01" `
                                -ManagementGroupId "$($MSEEEnvPrefix)-Platform" `
                                -topLevelManagementGroupPrefix $MSEEEnvPrefix `
                                -logAnalyticsWorkspaceName "opiw-plt-ue2-core-01" `
                                -workspaceRegion $Location `
                                -automationAccountName "aa-plt-eu2-core-01" `
                                -automationRegion $Location `
                                -Verbose

# OK - Assign Azure Policy to enforce Log Analytics workspace on the MSEE PARTNERS Managementg group 
New-AzManagementGroupDeployment -Name "$($DeploymentName)-PolicyAssignment-LogAnalyticsWorkspace" `
                                -Location $Location `
                                -TemplateFile ".\MSEE-DINE-LogAnalyticsPolicyAssignment.json" `
                                -retentionInDays "90" `
                                -rgName "rg-plt-ue2-core-01" `
                                -ManagementGroupId "$($MSEEEnvPrefix)-Partners" `
                                -topLevelManagementGroupPrefix $MSEEEnvPrefix `
                                -logAnalyticsWorkspaceName "opiw-plt-ue2-core-01" `
                                -workspaceRegion $Location `
                                -automationAccountName "aa-plt-eu2-core-01" `
                                -automationRegion $Location `
                                -Verbose

# OK - Could use parameters for LAW - Assign Azure Policy Initiative to enforce Diagnostic settings for subscriptions on top level management group
New-AzManagementGroupDeployment -Name "$($DeploymentName)-PolicyAssignment-DINE-ActivityLog" `
                                -Location $Location `
                                -TemplateFile ".\MSEE-DINE-ActivityLogPolicyAssignment.json" `
                                -topLevelManagementGroupPrefix $MSEEEnvPrefix `
                                -logAnalyticsResourceId "/subscriptions/$($PlatformSubscriptionId)/resourceGroups/rg-plt-ue2-core-01/providers/Microsoft.OperationalInsights/workspaces/opiw-plt-ue2-core-01" `
                                -ManagementGroupId $MSEEEnvPrefix `
                                -Verbose

# OK - Could use parameters for LAW - Assign Azure Policy Initiative to enforce Diagnostic settings for subscriptions on top level management group
New-AzManagementGroupDeployment -Name "$($DeploymentName)-PolicyAssignment-DINE-ResourceDiagnostics" `
                               -Location $Location `
                               -TemplateFile ".\MSEE-DINE-ResourceDiagnosticsPolicyAssignment.json" `
                               -topLevelManagementGroupPrefix $MSEEEnvPrefix `
                               -logAnalyticsResourceId "/subscriptions/$($PlatformSubscriptionId)/resourceGroups/rg-plt-ue2-core-01/providers/Microsoft.OperationalInsights/workspaces/opiw-plt-ue2-core-01" `
                               -ManagementGroupId $MSEEEnvPrefix `
                               -Verbose

# OK - Assign Azure Policy (initiative, already created before) to prevent Public endpoints
New-AzManagementGroupDeployment -Name "$($DeploymentName)-PolicyAssignment-DenyPublicEnpoints" `
                               -Location $Location `
                               -ManagementGroupId $MSEEEnvPrefix `
                               -TemplateFile ".\MSEE-DENY-PublicEndpointPolicyAssignment.json" `
                               -topLevelManagementGroupPrefix $MSEEEnvPrefix `
                               -Verbose

# OK - Assign Azure Policy to enforce Microsoft Defender for Cloud configuration enabled on all subscriptions, deployed to top level management group
New-AzManagementGroupDeployment -Name "$($DeploymentName)-PolicyAssignment-DefenderForCloud" `
                                -Location $Location `
                                -TemplateFile ".\MSEE-DINE-ASCConfigPolicyAssignment.json" `
                                -ManagementGroupId $MSEEEnvPrefix `
                                -topLevelManagementGroupPrefix $MSEEEnvPrefix `
                                -logAnalyticsResourceId "/subscriptions/$($PlatformSubscriptionId)/resourceGroups/rg-plt-ue2-core-01/providers/Microsoft.OperationalInsights/workspaces/opiw-plt-ue2-core-01" `
                                -enableAscForServers "DeployIfNotExists" `
                                -enableAscForSql "DeployIfNotExists" `
                                -enableAscForAppServices "DeployIfNotExists" `
                                -enableAscForStorage "DeployIfNotExists" `
                                -enableAscForRegistries "DeployIfNotExists" `
                                -enableAscForKeyVault "DeployIfNotExists" `
                                -enableAscForSqlOnVm "DeployIfNotExists" `
                                -enableAscForKubernetes "DeployIfNotExists" `
                                -enableAscForArm "DeployIfNotExists" `
                                -enableAscForDns "DeployIfNotExists" `
                                -enableAscForOssDb "DeployIfNotExists" `
                                -emailContactAsc $MSEESecurityContactEmailAddress `
                                -Verbose

# OK - Assign Azure Policy to enable Azure Security Benchmark, deployed to top level management group
New-AzManagementGroupDeployment -Name "$($DeploymentName)-PolicyAssignment-AzureSecurityBenchmark" `
                                -Location $Location `
                                -TemplateFile ".\MSEE-DINE-ASBPolicyAssignment.json" `
                                -ManagementGroupId $MSEEEnvPrefix `
                                -Verbose

# OK - NETWORK - Create connectivity hub, using traditional hub & spoke
#                We will not use Connectivity subscription, but Platform subscription instead (there would not be any AFW or any other published services - assumption, 
#               this could be changed. Because of this, there will be Management Subscription ID written in the  $ConnectivitySubscription ID!!

$ConnectivitySubscriptionId = $PlatformSubscriptionId
Select-AzSubscription -SubscriptionId $ConnectivitySubscriptionId #We will use Platform subscription instead Connectivity ($ConnectivitySubscriptionId)
New-AzSubscriptionDeployment -Name "$($DeploymentName)-Network-HubSpoke" `
                             -Location $Location `
                             -TemplateFile ".\MSEE-hubspoke-connectivity.json" `
                             -topLevelManagementGroupPrefix $MSEEEnvPrefix `
                             -connectivitySubscriptionId $ConnectivitySubscriptionId `
                             -addressPrefix $ConnectivityAddressPrefix `
                             -enableHub "vhub" `
                             -enableAzFw "No" `
                             -enableAzFwDnsProxy "No" `
                             -enableVpnGw "No" `
                             -enableErGw "No" `
                             -enableDdoS "No" `
                             -Verbose

# # NE RABIM! - The following example will first create a RESOURCE GROUP, and the subsequent deployment will create Private DNS Zone for Storage Account and AKV into that resource group
# # Because of this, there will be Management Subscription ID written in the  $ConnectivitySubscription ID!!
# $ConnectivitySubscriptionId = $PlatformSubscriptionId
# Select-AzSubscription -SubscriptionId $ConnectivitySubscriptionId #We will use Management subscription instead Connectivity ($ConnectivitySubscriptionId)
# New-AzSubscriptionDeployment -Name "$($DeploymentName)-RG-Connectivity" `
#                              -Location $Location `
#                              -TemplateFile "<NALASC-NAPAKA>.\MXDR-resourceGroup.json" `
#                              -rgName "rg-plt-ue2-network-01" `
#                              -locationFromTemplate $Location `
#                              -Verbose
# 
# Create Private DNS Zones for Azure PaaS services. 
# You must repeat this deployment for all Azure PaaS services as requested, and an updated table can be found at https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration
#
# Private DNS for Storage Account!
$ConnectivitySubscriptionId = $PlatformSubscriptionId
New-AzResourceGroupDeployment -Name "$($DeploymentName)-Connectivity-PrivateDNS-Storage" `
                              -ResourceGroupName "rg-plt-ue2-network-01" `
                              -TemplateFile ".\MSEE-privateDnsZones.json" `
                              -connectivityHubResourceId "/subscriptions/389a8786-8225-400e-9557-7802ca4093ff/resourceGroups/rg-plt-ue2-network-01/providers/Microsoft.Network/virtualNetworks/vnet-plt-ue2-core-01" `
                              -privateDnsZoneName "privatelink.blob.core.windows.net" `
                              -Verbose

# Because of this, there will be Management Subscription ID written in the  $ConnectivitySubscription ID!!
# OK - Private DNS for AKV!
$ConnectivitySubscriptionId = $PlatformSubscriptionId
New-AzResourceGroupDeployment -Name "$($DeploymentName)-Connectivity-PrivateDNS-KeyVault" `
                              -ResourceGroupName "rg-plt-ue2-network-01" `
                              -TemplateFile ".\MSEE-privateDnsZones.json" `
                              -connectivityHubResourceId "/subscriptions/389a8786-8225-400e-9557-7802ca4093ff/resourceGroups/rg-plt-ue2-network-01/providers/Microsoft.Network/virtualNetworks/vnet-plt-ue2-core-01" `
                              -privateDnsZoneName "privatelink.vaultcore.azure.net" `
                              -Verbose

# OK - Assign Azure Policy to prevent public IP usage in the (identity) Platform subscription 
# (GregorSu: I will NOT use IDENTITY subscription, Platform Instead and also Partner)
New-AzManagementGroupDeployment -Name "$($DeploymentName)-PolicyAssignment-DenyPublicIP" `
                                -Location $Location `
                                -ManagementGroupId "$($MSEEEnvPrefix)-Platform" `
                                -TemplateFile ".\MSEE-DENY-PublicIpAddressPolicyAssignment.json" `
                                -topLevelManagementGroupPrefix $MSEEEnvPrefix `
                                -Verbose

New-AzManagementGroupDeployment -Name "$($DeploymentName)-PolicyAssignment-DenyPublicIP" `
                                -Location $Location `
                                -ManagementGroupId "$($MSEEEnvPrefix)-Partners" `
                                -TemplateFile ".\MSEE-DENY-PublicIpAddressPolicyAssignment.json" `
                                -topLevelManagementGroupPrefix $MSEEEnvPrefix `
                                -Verbose

# Assign Azure Policy to deny IP forwarding on the landing zones management group (prevent VM to become a router) (https://github.com/Azure/Enterprise-Scale/blob/main/docs/reference/azpol.md#prevent-ip-forwarding-on-vms)
New-AzManagementGroupDeployment -Name "$($DeploymentName)-PolicyAssignment-PreventIPForwarding" `
                                -Location $Location `
                                -ManagementGroupId "$($MSEEEnvPrefix)" `
                                -TemplateFile ".\MSEE-DENY-IPForwardingPolicyAssignment.json" `
                                -Verbose

# OK - Assign Azure Policy to deny subnets without NSG in all environments! (maybe this would need to be changed and assign this policy to lower levels)
New-AzManagementGroupDeployment -Name "$($DeploymentName)-PolicyAssignment-NoSubnetdWithoutNGS" `
                                -Location $Location `
                                -ManagementGroupId "$($MSEEEnvPrefix)" `
                                -TemplateFile ".\MSEE-DENY-SubnetWithoutNsgPolicyAssignment.json" `
                                -topLevelManagementGroupPrefix $MSEEEnvPrefix `
                                -Verbose

# OK - Assign Azure Policy to deny RDP access from internet into VMs (domain controllers) in the (identity) ALL subscriptions
New-AzManagementGroupDeployment -Name "$($DeploymentName)-PolicyAssignment-DenyRDP" `
                                -Location $Location `
                                -ManagementGroupId "$($MSEEEnvPrefix)" `
                                -TemplateFile ".\MSEE-DENY-RDPFromInternetPolicyAssignment.json" `
                                -topLevelManagementGroupPrefix $MSEEEnvPrefix `
                                -Verbose

# OK - Assign Azure Policy to deny usage of storage accounts over http everywhere 
New-AzManagementGroupDeployment -Name "$($DeploymentName)-PolicyAssignment-DenyHTTP" `
                                -Location $Location `
                                -ManagementGroupId "$($MSEEEnvPrefix)" `
                                -TemplateFile ".\MSEE-DENY-StorageWithoutHttpsPolicyAssignment.json" `
                                -Verbose

# OK - Assign Azure Policy to enforce TLS/SSL on the landing zones management group
New-AzManagementGroupDeployment -Name "$($DeploymentName)-PolicyAssignment-Enforce-TLSSSL" `
                                -Location $Location `
                                -ManagementGroupId "$($MSEEEnvPrefix)" `
                                -TemplateFile ".\MSEE-DENY-DINE-Append-TLS-SSL-PolicyAssignment.json" `
                                -topLevelManagementGroupPrefix $MSEEEnvPrefix `
                                -Verbose

# OK - Assign Azure Policy to enable Auto provision Log Analyzics Agent on all subscriptions (for VMs and VMSS)
New-AzManagementGroupDeployment -Name "$($DeploymentName)-PolicyAssignment-Enforce-LAAgentOnVMs" `
                                -Location $Location `
                                -ManagementGroupId "$($MSEEEnvPrefix)" `
                                -logAnalyticsResourceId "/subscriptions/$($PlatformSubscriptionId)/resourceGroups/rg-plt-ue2-core-01/providers/Microsoft.OperationalInsights/workspaces/opiw-plt-ue2-core-01" `
                                -TemplateFile ".\MSEE-DINE-VMMonitoringPolicyAssignment.json" `
                                -topLevelManagementGroupPrefix $MSEEEnvPrefix `
                                -Verbose

# OK - Assign Azure Policy to enable Auto provision Log Analyzics Agent on all subscriptions (for VMs and VMSS)
New-AzManagementGroupDeployment -Name "$($DeploymentName)-PolicyAssignment-Enforce-LAAgentOnVMSS" `
                                -Location $Location `
                                -ManagementGroupId "$($MSEEEnvPrefix)" `
                                -logAnalyticsResourceId "/subscriptions/$($PlatformSubscriptionId)/resourceGroups/rg-plt-ue2-core-01/providers/Microsoft.OperationalInsights/workspaces/opiw-plt-ue2-core-01" `
                                -TemplateFile ".\MSEE-DINE-VMSSMonitoringPolicyAssignment.json" `
                                -topLevelManagementGroupPrefix $MSEEEnvPrefix `
                                -Verbose
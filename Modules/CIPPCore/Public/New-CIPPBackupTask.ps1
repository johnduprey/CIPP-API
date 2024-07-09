function New-CIPPBackupTask {
    [CmdletBinding()]
    param (
        $Task,
        $TenantFilter
    )

    $BackupData = switch ($Task) {
        'users' {
            Write-Host "Backup users for $TenantFilter"
            $Users = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/users?$top=999' -tenantid $TenantFilter | Select-Object * -ExcludeProperty mail, provisionedPlans, onPrem*, *passwordProfile*, *serviceProvisioningErrors*, isLicenseReconciliationNeeded, isManagementRestricted, isResourceAccount, *date*, *external*, identities, deletedDateTime, isSipEnabled, assignedPlans, cloudRealtimeCommunicationInfo, deviceKeys, provisionedPlan, securityIdentifier
            #remove the property if the value is $null
            $Users | ForEach-Object {
                $_.psobject.properties | Where-Object { $_.Value -eq $null } | ForEach-Object {
                    $_.psobject.properties.Remove($_.Name)
                }
            }
            $Users
        }
        'groups' {
            Write-Host "Backup groups for $TenantFilter"
            New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/groups?$top=999' -tenantid $TenantFilter
        }
        'ca' {
            Write-Host "Backup Conditional Access Policies for $TenantFilter"
            $Policies = New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/conditionalAccess/policies?$top=999' -tenantid $TenantFilter
            $Policies | ForEach-Object {
                New-CIPPCATemplate -TenantFilter $TenantFilter -JSON $_ -ErrorAction SilentlyContinue
            }
        }
        'intuneconfig' {
            $GraphURLS = @("https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$select=id,displayName,lastModifiedDateTime,roleScopeTagIds,microsoft.graph.unsupportedDeviceConfiguration/originalEntityTypeName&`$expand=assignments&top=1000"
                'https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles'
                "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations?`$expand=assignments&top=999"
                "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppConfigurations?`$expand=assignments&`$filter=microsoft.graph.androidManagedStoreAppConfiguration/appSupportsOemConfig%20eq%20true"
                'https://graph.microsoft.com/beta/deviceManagement/configurationPolicies'
            )

            $GraphURLS | ForEach-Object {
                $URLName = (($_).split('?') | Select-Object -First 1) -replace 'https://graph.microsoft.com/beta/deviceManagement/', ''
                New-GraphGetRequest -uri "$($_)" -tenantid $TenantFilter
            } | ForEach-Object {
                New-CIPPIntuneTemplate -TenantFilter $TenantFilter -URLName $URLName -ID $_.ID
            }
        }
        'intunecompliance' {
            New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies?$top=999' -tenantid $TenantFilter | ForEach-Object {
                New-CIPPIntuneTemplate -TenantFilter $TenantFilter -URLName 'deviceCompliancePolicies' -ID $_.ID
            }
        }

        'intuneprotection' {
            New-GraphGetRequest -uri 'https://graph.microsoft.com/beta/deviceAppManagement/managedAppPolicies?$top=999' -tenantid $TenantFilter | ForEach-Object {
                New-CIPPIntuneTemplate -TenantFilter $TenantFilter -URLName 'managedAppPolicies' -ID $_.ID
            }
        }

        'CippWebhookAlerts' {
            Write-Host "Backup Webhook Alerts for $TenantFilter"
            $WebhookTable = Get-CIPPTable -TableName 'WebhookRules'
            Get-CIPPAzDataTableEntity @WebhookTable | Where-Object { $TenantFilter -in ($_.Tenants | ConvertFrom-Json).fullvalue.defaultDomainName }
        }
        'CippScriptedAlerts' {
            Write-Host "Backup Scripted Alerts for $TenantFilter"
            $ScheduledTasks = Get-CIPPTable -TableName 'ScheduledTasks'
            Get-CIPPAzDataTableEntity @ScheduledTasks | Where-Object { $_.hidden -eq $true -and $_.command -like 'Get-CippAlert*' -and $TenantFilter -in $_.Tenant }
        }
        'CippStandards' {
            Write-Host "Backup Standards for $TenantFilter"
            $Table = Get-CippTable -tablename 'standards'
            $Filter = "PartitionKey eq 'standards' and RowKey eq '$($TenantFilter)'"
            (Get-CIPPAzDataTableEntity @Table -Filter $Filter)
        }

    }
    return $BackupData
}

# ==============================================================
# Dataverse Solution Component Inventory Script - Change Summary
# ==============================================================
#
# Purpose:
# This script inventories Dataverse solution components and resolves
# component types, display names, and logical names where possible.
#
# The previous version had issues where some components were shown as
# "Unknown", missing names, or incorrect component types. The fixes below
# improve component type resolution reliability.
#
#
# --------------------------------------------------------------
# Additional Component Support Added
# --------------------------------------------------------------
#
# Added mappings/resolution support for:
#
# - Mail Merge Template
# - Team Template
# - Entity Key
# - Privilege
# - Attribute Image Configuration
# - Entity Image Configuration
# - Entity Relationship
#
# These use Dataverse metadata where possible.
#
#
# --------------------------------------------------------------
# Known Limitations
# --------------------------------------------------------------
#
# Some solution components do not have standalone records with names.
# These will correctly show the ComponentType but no DisplayName.
#
# Examples:
#
# - Ribbon Customization
# - Ribbon Command
# - Ribbon Rule
# - Ribbon Diff
# - Relationship sub-components
# - Role Privileges
# - Field Permissions
# - SLA Items
# - Routing Rule Items
#
#
# --------------------------------------------------------------
# AI Component Limitation
# --------------------------------------------------------------
#
# Component Types:
#
#   400 - AI Project Type
#   401 - AI Project
#
# are valid Dataverse component types.
#
# However, the underlying Dataverse table/schema could not be confirmed
# through public metadata documentation.
#
# These components are intentionally not mapped to avoid incorrect
# entity lookups.
#
# Diagnostic output can be used to identify their actual backing entity
# within the environment.
#
#
# --------------------------------------------------------------
# Overall Improvements
# --------------------------------------------------------------
#
# The script now:
#
# Resolves component types independently from Dataverse labels
# Prevents SCF metadata from overriding known mappings
# Handles newer component types correctly
# Supports large numeric component IDs
# Resolves more entity-backed components automatically
# Provides accurate ComponentType values for all solution components
#
# Name resolution remains dependent on whether the component has a
# queryable Dataverse record or metadata object.
#
# ==============================================================

$conn = Get-CrmConnection -InteractiveMode

$componentTypeMap = @{
    1   = "Entity"
    2   = "Attribute"
    3   = "Relationship"
    4   = "Attribute Picklist Value"
    5   = "Attribute Lookup Value"
    6   = "View Attribute"
    7   = "Localized Label"
    8   = "Relationship Extra Condition"
    9   = "Option Set"
    10  = "Entity Relationship"
    11  = "Entity Relationship Role"
    12  = "Entity Relationship Relationships"
    13  = "Managed Property"
    14  = "Entity Key"
    16  = "Privilege"
    17  = "PrivilegeObjectTypeCode"
    18  = "Index"
    20  = "Role"
    21  = "Role Privilege"
    22  = "Display String"
    23  = "Display String Map"
    24  = "Form"
    25  = "Organization"
    26  = "Saved Query"
    29  = "Workflow"
    31  = "Report"
    32  = "Report Entity"
    33  = "Report Category"
    34  = "Report Visibility"
    35  = "Attachment"
    36  = "Email Template"
    37  = "Contract Template"
    38  = "KB Article Template"
    39  = "Mail Merge Template"
    44  = "Duplicate Rule"
    45  = "Duplicate Rule Condition"
    46  = "Entity Map"
    47  = "Attribute Map"
    48  = "Ribbon Command"
    49  = "Ribbon Context Group"
    50  = "Ribbon Customization"
    52  = "Ribbon Rule"
    53  = "Ribbon Tab To Command Map"
    55  = "Ribbon Diff"
    59  = "Saved Query Visualization"
    60  = "System Form"
    61  = "Web Resource"
    62  = "Site Map"
    63  = "Connection Role"
    64  = "Complex Control"
    65  = "Hierarchy Rule"
    66  = "Custom Control"
    68  = "Custom Control Default Config"
    70  = "Field Security Profile"
    71  = "Field Permission"
    80  = "Model-driven App"
    90  = "Plugin Type"
    91  = "Plugin Assembly"
    92  = "SDK Message Processing Step"
    93  = "SDK Message Processing Step Image"
    95  = "Service Endpoint"
    150 = "Routing Rule"
    151 = "Routing Rule Item"
    152 = "SLA"
    153 = "SLA Item"
    154 = "Convert Rule"
    155 = "Convert Rule Item"
    161 = "Mobile Offline Profile"
    162 = "Mobile Offline Profile Item"
    165 = "Similarity Rule"
    166 = "Data Source Mapping"
    201 = "SDKMessage"
    202 = "SDKMessageFilter"
    203 = "SdkMessagePair"
    204 = "SdkMessageRequest"
    205 = "SdkMessageRequestField"
    206 = "SdkMessageResponse"
    207 = "SdkMessageResponseField"
    208 = "Import Map"
    210 = "WebWizard"
    300 = "Canvas App"
    371 = "Connector"
    372 = "Connector"
    380 = "Environment Variable Definition"
    381 = "Environment Variable Value"
    400 = "AI Project Type"
    401 = "AI Project"
    402 = "AI Configuration"
    430 = "Entity Analytics Configuration"
    431 = "Attribute Image Configuration"
    432 = "Entity Image Configuration"
    900001 = "Dashboard"
    900002 = "Custom API"
    900003 = "Custom API Request Parameter"
    900004 = "Custom API Response Property"
    900005 = "Connection Reference"
    900007 = "Dataflow"
}


$componentTypeNameToId = @{}

foreach ($kvp in $componentTypeMap.GetEnumerator()) {

    $componentTypeNameToId[$kvp.Value] = $kvp.Key

}



# --------------------------------------------------------------
# Overwrite With Authoritative Labels From Org Metadata
# --------------------------------------------------------------
Write-Host "Retrieving authoritative componenttype option set..." `
    -ForegroundColor Cyan

try {

    $componentTypeAttrRequest = New-Object Microsoft.Xrm.Sdk.Messages.RetrieveAttributeRequest
    $componentTypeAttrRequest.EntityLogicalName = "solutioncomponent"
    $componentTypeAttrRequest.LogicalName = "componenttype"
    $componentTypeAttrRequest.RetrieveAsIfPublished = $true

    $componentTypeAttrResponse = $conn.Execute($componentTypeAttrRequest)

    $componentTypeOptions = $componentTypeAttrResponse.AttributeMetadata.OptionSet.Options

    $liveCount = 0

    foreach ($opt in $componentTypeOptions) {

        $optValue = $opt.Value
        $optLabel = $opt.Value.ToString()

        if ($opt.Label -and $opt.Label.UserLocalizedLabel) {

            $optLabel = $opt.Label.UserLocalizedLabel.Label

        }


        $componentTypeMap[$optValue] = $optLabel
        $componentTypeNameToId[$optLabel] = $optValue

        $liveCount++

    }


    Write-Host "Refreshed $liveCount componenttype labels from live org metadata" `
        -ForegroundColor Cyan

}
catch {

    Write-Host "Failed to retrieve live componenttype metadata - falling back to the static table above: $($_.Exception.Message)" `
        -ForegroundColor Red

}



# --------------------------------------------------------------
# Helper: unwrap a raw OptionSetValue regardless of nesting depth
# --------------------------------------------------------------
function Get-RawOptionSetInt {

param(
    $InputValue
)

$current = $InputValue

for ($i = 0; $i -lt 5; $i++) {

    if ($null -eq $current) { return $null }

    if ($current -is [int]) { return $current }

    if ($current -is [Microsoft.Xrm.Sdk.OptionSetValue]) {

        $current = $current.Value
        continue

    }

    if ($current.PSObject -and
        $current.PSObject.Properties.Match('Value').Count -gt 0) {

        $current = $current.Value
        continue

    }

    break

}

if ($current -is [int]) { return $current }

return $null

}



# --------------------------------------------------------------
# Helper: parse a numeric string that may be thousands-separated
# --------------------------------------------------------------
function Get-CleanInt {

param(
    $InputValue
)

if ($null -eq $InputValue) { return $null }

$str = $InputValue.ToString().Trim() -replace ',', ''

if ($str -match '^\d+$') {

    return [int]$str

}

return $null

}



# --------------------------------------------------------------
# Preload SCF (Solution Component Framework) Type Definitions
# --------------------------------------------------------------
Write-Host "Retrieving SCF (Solution Component Framework) type definitions..." `
    -ForegroundColor Cyan

try {

    $scfFetch = @"
<fetch>
 <entity name='solutioncomponentdefinition'>
  <attribute name='name'/>
  <attribute name='objecttypecode'/>
 </entity>
</fetch>
"@

    $scfResults = Get-CrmRecordsByFetch `
        -conn $conn `
        -Fetch $scfFetch `
        -AllRows

    $scfCount = 0
    $scfAlreadyKnown = 0
    $scfSkipped = 0
    $scfSkippedReasons = @{}


    # --------------------------------------------------------------
    # Diagnostic capture: exact ground-truth rows for Team Template /
    # AI Project, straight from solutioncomponentdefinition, with NO
    # interpretation applied. This is printed after the loop below so
    # you can see precisely what (if anything) the org has on file for
    # these, instead of us guessing.
    # --------------------------------------------------------------

    $scfNamesOfInterest = @()


    foreach ($scf in $scfResults.CrmRecords) {

        if ($scf.name -and $scf.name -match 'Team Template|AI Project') {

            $scfNamesOfInterest += [PSCustomObject]@{
                ObjectTypeCode = $scf.objecttypecode
                Name           = $scf.name
            }

        }


        $scfTypeId = Get-RawOptionSetInt $scf.objecttypecode

        if ($null -eq $scfTypeId) {
            $scfTypeId = Get-CleanInt $scf.objecttypecode
        }


        if ($null -ne $scfTypeId -and $scf.name) {

            if ($componentTypeMap.ContainsKey($scfTypeId)) {
                $scfAlreadyKnown++
            }
            else {

                $componentTypeMap[$scfTypeId] = $scf.name
                $componentTypeNameToId[$scf.name] = $scfTypeId

                $scfCount++

            }

        }
        else {
            $scfSkipped++

            if ($null -eq $scfTypeId) {

                $reasonKey = "objecttypecode could not be parsed as a number (raw value: '$($scf.objecttypecode)')"

            }
            else {

                $reasonKey = "objecttypecode parsed fine ($scfTypeId) but the 'name' field was blank"

            }

            if ($scfSkippedReasons.ContainsKey($reasonKey)) {

                $scfSkippedReasons[$reasonKey]++

            }
            else {

                $scfSkippedReasons[$reasonKey] = 1

            }

        }

    }

    Write-Host "Merged $scfCount NEW SCF component type definitions into the type map ($scfAlreadyKnown already-known ids were left untouched, not overwritten)" `
        -ForegroundColor Cyan


    # --------------------------------------------------------------
    # Diagnostic: exact Team Template / AI Project rows on file
    # --------------------------------------------------------------

    if ($scfNamesOfInterest.Count -gt 0) {

        Write-Host "  -> solutioncomponentdefinition rows matching 'Team Template' or 'AI Project':" `
            -ForegroundColor Yellow

        foreach ($n in $scfNamesOfInterest) {

            Write-Host "       objecttypecode=$($n.ObjectTypeCode)  name='$($n.Name)'" `
                -ForegroundColor Yellow

        }

    }
    else {

        Write-Host "  -> No solutioncomponentdefinition rows matched 'Team Template' or 'AI Project' - if those component types exist in your org, they're coming from somewhere other than this table (check the general 'Unknown (n)' diagnostic at the bottom of the script instead)." `
            -ForegroundColor Yellow

    }


    # --------------------------------------------------------------
    # Diagnostic: SCF rows that failed to parse
    # --------------------------------------------------------------
    if ($scfSkipped -gt 0) {

        Write-Host "  -> $scfSkipped solutioncomponentdefinition row(s) were skipped and could NOT be added to the type map:" `
            -ForegroundColor Yellow

        foreach ($reason in $scfSkippedReasons.Keys) {

            Write-Host "       - $($scfSkippedReasons[$reason])x : $reason" `
                -ForegroundColor Yellow

        }

    }

}
catch {

    Write-Host "Failed to retrieve solutioncomponentdefinition - SCF component types will keep showing as 'Unknown (n)': $($_.Exception.Message)" `
        -ForegroundColor Red

}



# --------------------------------------------------------------
# Get Solution Components
# --------------------------------------------------------------

$fetch = @"
<fetch>
 <entity name='solutioncomponent'>

   <attribute name='solutioncomponentid'/>
   <attribute name='componenttype'/>
   <attribute name='objectid'/>

   <link-entity name='solution'
                from='solutionid'
                to='solutionid'
                alias='sol'>

        <attribute name='friendlyname'/>
        <attribute name='uniquename'/>
        <attribute name='version'/>
        <attribute name='ismanaged'/>

   </link-entity>

 </entity>
</fetch>
"@


$results = Get-CrmRecordsByFetch `
    -conn $conn `
    -Fetch $fetch `
    -AllRows


Write-Host "Retrieved $($results.CrmRecords.Count) solution components" `
    -ForegroundColor Cyan



# --------------------------------------------------------------
# Component Name Cache
# --------------------------------------------------------------

$nameCache = @{}



# --------------------------------------------------------------
# Preload Entity/Attribute/Relationship/Key/Privilege Metadata
# --------------------------------------------------------------
Write-Host "Retrieving entity, attribute, relationship, key, and privilege metadata..." `
    -ForegroundColor Cyan

$entityMetadataById       = @{}
$attributeMetadataById    = @{}
$relationshipMetadataById = @{}
$keyMetadataById          = @{}
$privilegeMetadataById    = @{}

try {

    $metaRequest = New-Object Microsoft.Xrm.Sdk.Messages.RetrieveAllEntitiesRequest
    $metaRequest.EntityFilters =
        [Microsoft.Xrm.Sdk.Metadata.EntityFilters]::Entity -bor `
        [Microsoft.Xrm.Sdk.Metadata.EntityFilters]::Attributes -bor `
        [Microsoft.Xrm.Sdk.Metadata.EntityFilters]::Relationships -bor `
        [Microsoft.Xrm.Sdk.Metadata.EntityFilters]::Privileges
    $metaRequest.RetrieveAsIfPublished = $true

    $metaResponse = $conn.Execute($metaRequest)


    foreach ($em in $metaResponse.EntityMetadata) {

        $displayLabel = $em.LogicalName

        if ($em.DisplayName -and $em.DisplayName.UserLocalizedLabel) {

            $displayLabel = $em.DisplayName.UserLocalizedLabel.Label

        }


        $entityMetadataById[$em.MetadataId.ToString().ToLower()] =
            [PSCustomObject]@{
                DisplayName = $displayLabel
                LogicalName = $em.LogicalName
            }


        # Attribute metadata is nested under each entity, so build
        # the attribute lookup in the same pass.

        if ($em.Attributes) {

            foreach ($attr in $em.Attributes) {

                $attrLabel = $attr.LogicalName

                if ($attr.DisplayName -and $attr.DisplayName.UserLocalizedLabel) {

                    $attrLabel = $attr.DisplayName.UserLocalizedLabel.Label

                }


                $attributeMetadataById[$attr.MetadataId.ToString().ToLower()] =
                    [PSCustomObject]@{
                        DisplayName = $attrLabel
                        LogicalName = $attr.LogicalName
                    }

            }

        }
        foreach ($relCollection in @(
            $em.OneToManyRelationships,
            $em.ManyToOneRelationships,
            $em.ManyToManyRelationships
        )) {

            if (-not $relCollection) { continue }

            foreach ($rel in $relCollection) {

                $relationshipMetadataById[$rel.MetadataId.ToString().ToLower()] =
                    [PSCustomObject]@{
                        DisplayName = $rel.SchemaName
                        LogicalName = $rel.SchemaName
                    }

            }

        }

        if ($em.Keys) {

            foreach ($key in $em.Keys) {

                $keyLabel = $key.LogicalName

                if ($key.DisplayName -and $key.DisplayName.UserLocalizedLabel) {

                    $keyLabel = $key.DisplayName.UserLocalizedLabel.Label

                }


                $keyMetadataById[$key.MetadataId.ToString().ToLower()] =
                    [PSCustomObject]@{
                        DisplayName = $keyLabel
                        LogicalName = $key.LogicalName
                    }

            }

        }
        if ($em.Privileges) {

            foreach ($priv in $em.Privileges) {

                $privilegeMetadataById[$priv.PrivilegeId.ToString().ToLower()] =
                    [PSCustomObject]@{
                        DisplayName = $priv.Name
                        LogicalName = $priv.Name
                    }

            }

        }

    }


    Write-Host "Cached metadata for $($entityMetadataById.Count) entities, $($attributeMetadataById.Count) attributes, $($relationshipMetadataById.Count) relationships, $($keyMetadataById.Count) keys, $($privilegeMetadataById.Count) privileges" `
        -ForegroundColor Cyan

}
catch {

    Write-Host "Failed to preload entity/attribute/relationship/key/privilege metadata: $($_.Exception.Message)" `
        -ForegroundColor Red

}



# --------------------------------------------------------------
# Preload Global Option Set Metadata
# --------------------------------------------------------------
Write-Host "Retrieving global option set metadata..." -ForegroundColor Cyan

$optionSetMetadataById = @{}

try {

    $optionSetRequest = New-Object Microsoft.Xrm.Sdk.Messages.RetrieveAllOptionSetsRequest

    $optionSetResponse = $conn.Execute($optionSetRequest)


    foreach ($os in $optionSetResponse.OptionSetMetadata) {

        $osLabel = $os.Name

        if ($os.DisplayName -and $os.DisplayName.UserLocalizedLabel) {

            $osLabel = $os.DisplayName.UserLocalizedLabel.Label

        }


        $optionSetMetadataById[$os.MetadataId.ToString().ToLower()] =
            [PSCustomObject]@{
                DisplayName = $osLabel
                LogicalName = $os.Name
            }

    }


    Write-Host "Cached metadata for $($optionSetMetadataById.Count) global option sets" `
        -ForegroundColor Cyan

}
catch {

    Write-Host "Failed to preload option set metadata: $($_.Exception.Message)" `
        -ForegroundColor Red

}



# --------------------------------------------------------------
# Component Type -> Entity/Field Mapping
# --------------------------------------------------------------
$componentEntityMap = @{

    # Views/forms
    "Saved Query"                = @{ Entity = "savedquery";                    PrimaryKey = "savedqueryid";                    NameField = "name";                            LogicalField = "name" }
    "Form"                       = @{ Entity = "systemform";                    PrimaryKey = "formid";                          NameField = "name";                            LogicalField = "name" }
    "System Form"                = @{ Entity = "systemform";                    PrimaryKey = "formid";                          NameField = "name";                            LogicalField = "name" }

    # Automation
    "Workflow"                   = @{ Entity = "workflow";                      PrimaryKey = "workflowid";                      NameField = "name";                            LogicalField = "name" }

    # Reporting / templates
    "Report"                     = @{ Entity = "report";                       PrimaryKey = "reportid";                        NameField = "name";                            LogicalField = "name" }
    "Email Template"             = @{ Entity = "template";                     PrimaryKey = "templateid";                      NameField = "title";                           LogicalField = "title" }
    "Contract Template"          = @{ Entity = "contracttemplate";             PrimaryKey = "contracttemplateid";              NameField = "name";                            LogicalField = "name" }
    "KB Article Template"        = @{ Entity = "kbarticletemplate";            PrimaryKey = "kbarticletemplateid";             NameField = "title";                           LogicalField = "title" }
    "Mail Merge Template"        = @{ Entity = "mailmergetemplate";            PrimaryKey = "mailmergetemplateid";             NameField = "name";                            LogicalField = "name" }
    "Team Template"              = @{ Entity = "teamtemplate";                 PrimaryKey = "teamtemplateid";                  NameField = "teamtemplatename";                LogicalField = "teamtemplatename" }

    # Data quality / integration
    "Duplicate Rule"             = @{ Entity = "duplicaterule";                PrimaryKey = "duplicateruleid";                 NameField = "name";                            LogicalField = "name" }
    "Import Map"                 = @{ Entity = "importmap";                    PrimaryKey = "importmapid";                     NameField = "name";                            LogicalField = "name" }

    # UI/security building blocks
    "Role"                       = @{ Entity = "role";                         PrimaryKey = "roleid";                          NameField = "name";                            LogicalField = "name" }
    "Web Resource"                = @{ Entity = "webresource";                  PrimaryKey = "webresourceid";                   NameField = "name";                            LogicalField = "name" }

    # diagnostic further down for the more likely cause.
    "Site Map"                   = @{ Entity = "sitemap";                      PrimaryKey = "sitemapid";                       NameField = "sitemapname";                     LogicalField = "sitemapnameunique" }
    "Connection Role"            = @{ Entity = "connectionrole";               PrimaryKey = "connectionroleid";                NameField = "name";                            LogicalField = "name" }
    "Custom Control"             = @{ Entity = "customcontrol";                PrimaryKey = "customcontrolid";                 NameField = "name";                            LogicalField = "name" }
    "Field Security Profile"     = @{ Entity = "fieldsecurityprofile";         PrimaryKey = "fieldsecurityprofileid";          NameField = "name";                            LogicalField = "name" }
    "Hierarchy Rule"             = @{ Entity = "hierarchyrule";                PrimaryKey = "hierarchyruleid";                 NameField = "name";                            LogicalField = "name" }

    # Plugins / SDK / service integration
    "Plugin Type"                = @{ Entity = "plugintype";                   PrimaryKey = "plugintypeid";                    NameField = "name";                            LogicalField = "typename" }
    "Plugin Assembly"            = @{ Entity = "pluginassembly";               PrimaryKey = "pluginassemblyid";                NameField = "name";                            LogicalField = "name" }
    "SDK Message Processing Step" = @{ Entity = "sdkmessageprocessingstep";     PrimaryKey = "sdkmessageprocessingstepid";      NameField = "name";                            LogicalField = "name" }
    "Service Endpoint"           = @{ Entity = "serviceendpoint";              PrimaryKey = "serviceendpointid";               NameField = "name";                            LogicalField = "name" }
    "SDKMessage"                 = @{ Entity = "sdkmessage";                   PrimaryKey = "sdkmessageid";                    NameField = "name";                            LogicalField = "name" }
    "SDK Message"                = @{ Entity = "sdkmessage";                   PrimaryKey = "sdkmessageid";                    NameField = "name";                            LogicalField = "name" }
    "SDKMessageFilter"           = @{ Entity = "sdkmessagefilter";             PrimaryKey = "sdkmessagefilterid";              NameField = "primaryobjecttypecode";           LogicalField = "primaryobjecttypecode" }
    "SDK Message Filter"         = @{ Entity = "sdkmessagefilter";             PrimaryKey = "sdkmessagefilterid";              NameField = "primaryobjecttypecode";           LogicalField = "primaryobjecttypecode" }

    # Service scheduling
    "SLA"                        = @{ Entity = "sla";                         PrimaryKey = "slaid";                           NameField = "name";                            LogicalField = "name" }

    # Mobile / similarity
    "Mobile Offline Profile"     = @{ Entity = "mobileofflineprofile";        PrimaryKey = "mobileofflineprofileid";          NameField = "name";                            LogicalField = "name" }
    "Dashboard"                  = @{ Entity = "systemform";                   PrimaryKey = "formid";                          NameField = "name";                            LogicalField = "name" }
    "Custom API"                 = @{ Entity = "customapi";                    PrimaryKey = "customapiid";                     NameField = "displayname";                     LogicalField = "uniquename" }
    "CustomAPI"                  = @{ Entity = "customapi";                    PrimaryKey = "customapiid";                     NameField = "displayname";                     LogicalField = "uniquename" }
    "Custom API Request Parameter"  = @{ Entity = "customapirequestparameter"; PrimaryKey = "customapirequestparameterid";    NameField = "displayname";                     LogicalField = "uniquename" }
    "CustomAPIRequestParameter"     = @{ Entity = "customapirequestparameter"; PrimaryKey = "customapirequestparameterid";    NameField = "displayname";                     LogicalField = "uniquename" }
    "Custom API Response Property"  = @{ Entity = "customapiresponseproperty"; PrimaryKey = "customapiresponsepropertyid";    NameField = "displayname";                     LogicalField = "uniquename" }
    "CustomAPIResponseProperty"     = @{ Entity = "customapiresponseproperty"; PrimaryKey = "customapiresponsepropertyid";    NameField = "displayname";                     LogicalField = "uniquename" }
    "Connection Reference"       = @{ Entity = "connectionreference";          PrimaryKey = "connectionreferenceid";           NameField = "connectionreferencedisplayname"; LogicalField = "connectionreferencelogicalname" }
    "Model-driven App"           = @{ Entity = "appmodule";                    PrimaryKey = "appmoduleid";                     NameField = "name";                            LogicalField = "uniquename" }
    "Canvas App"                 = @{ Entity = "canvasapp";                    PrimaryKey = "canvasappid";                     NameField = "displayname";                     LogicalField = "name" }

    # Environment variables
    "Environment Variable Definition" = @{ Entity = "environmentvariabledefinition"; PrimaryKey = "environmentvariabledefinitionid"; NameField = "displayname"; LogicalField = "schemaname" }

}



# --------------------------------------------------------------
# Bulk Preload Every Mapped Entity Type
# --------------------------------------------------------------
$bulkLookup = @{}

foreach ($typeLabel in $componentEntityMap.Keys) {

    $map = $componentEntityMap[$typeLabel]

    Write-Host "Preloading $($map.Entity) records (component type '$typeLabel')..." `
        -ForegroundColor Cyan

    $bulkLookup[$typeLabel] = @{}

    try {

        $fetchAll = @"
<fetch>
 <entity name='$($map.Entity)'>
  <attribute name='$($map.PrimaryKey)'/>
  <attribute name='$($map.NameField)'/>
  <attribute name='$($map.LogicalField)'/>
 </entity>
</fetch>
"@

        $allRecords = Get-CrmRecordsByFetch `
            -conn $conn `
            -Fetch $fetchAll `
            -AllRows


        foreach ($rec in $allRecords.CrmRecords) {
            $key = $rec.($map.PrimaryKey).ToString().ToLower()

            $bulkLookup[$typeLabel][$key] =
                [PSCustomObject]@{
                    DisplayName = $rec.($map.NameField)
                    LogicalName = $rec.($map.LogicalField)
                }

        }


        Write-Host "  -> cached $($allRecords.CrmRecords.Count) $($map.Entity) records" `
            -ForegroundColor Cyan

    }
    catch {

        Write-Host "  -> failed preloading $($map.Entity) (component type '$typeLabel'): $($_.Exception.Message)" `
            -ForegroundColor Red

    }

}



# --------------------------------------------------------------
# Diagnostic: Site Map ObjectIds not found in the bulk sitemap preload
# --------------------------------------------------------------
if ($componentEntityMap.ContainsKey("Site Map") -and
    $bulkLookup.ContainsKey("Site Map")) {

    $siteMapObjectIdsSeen = $results.CrmRecords |
        Where-Object {
            $_.componenttype -eq "Site Map" -or
            ($_.objectid -and $componentTypeMap[(Get-RawOptionSetInt $_.componenttype_Property)] -eq "Site Map")
        } |
        Select-Object -ExpandProperty objectid -Unique

    if ($siteMapObjectIdsSeen -and $siteMapObjectIdsSeen.Count -gt 0) {

        $siteMapMissing = @()

        foreach ($sid in $siteMapObjectIdsSeen) {

            $sidLower = $sid.ToString().ToLower()

            if (-not $bulkLookup["Site Map"].ContainsKey($sidLower)) {

                $siteMapMissing += $sidLower

            }

        }

        Write-Host "Site Map check: $($siteMapObjectIdsSeen.Count) distinct ObjectId(s) referenced, $($siteMapMissing.Count) not found in the bulk 'sitemap' table preload" `
            -ForegroundColor Yellow

        if ($siteMapMissing.Count -gt 0) {

            Write-Host "  -> sample missing ObjectId(s) - look these up directly (Web API GET /sitemaps(<guid>) or Advanced Find) to confirm whether they genuinely don't exist as sitemap records in this org:" `
                -ForegroundColor Yellow

            $siteMapMissing | Select-Object -First 5 | ForEach-Object {

                Write-Host "       $_" -ForegroundColor Yellow

            }

        }

    }

}



# --------------------------------------------------------------
# Resolve Component Details
# --------------------------------------------------------------
function Get-ComponentDetails {

param(
    [int]$TypeId,
    [string]$TypeName,
    [string]$ObjectId
)


$result = [PSCustomObject]@{

    DisplayName = ""
    LogicalName = ""

}



if ([string]::IsNullOrEmpty($ObjectId)) {

    return $result

}

$ObjectId = $ObjectId.ToLower()


if ($TypeName) {

    $TypeName = $TypeName.Trim()

}


$cacheKey = "$TypeId-$ObjectId"



if ($nameCache.ContainsKey($cacheKey)) {

    return $nameCache[$cacheKey]

}



try {


    # Metadata-backed types go through the Metadata API dictionaries
    # preloaded above, not Get-CrmRecord / FetchXml.

    if ($TypeId -eq 1) {

        if ($entityMetadataById.ContainsKey($ObjectId)) {

            $meta = $entityMetadataById[$ObjectId]

            $result.DisplayName = $meta.DisplayName
            $result.LogicalName = $meta.LogicalName

        }

    }
    elseif ($TypeId -eq 2) {

        if ($attributeMetadataById.ContainsKey($ObjectId)) {

            $meta = $attributeMetadataById[$ObjectId]

            $result.DisplayName = $meta.DisplayName
            $result.LogicalName = $meta.LogicalName

        }

    }
    elseif ($TypeId -eq 3) {

        if ($relationshipMetadataById.ContainsKey($ObjectId)) {

            $meta = $relationshipMetadataById[$ObjectId]

            $result.DisplayName = $meta.DisplayName
            $result.LogicalName = $meta.LogicalName

        }

    }
    elseif ($TypeId -eq 9) {

        if ($optionSetMetadataById.ContainsKey($ObjectId)) {

            $meta = $optionSetMetadataById[$ObjectId]

            $result.DisplayName = $meta.DisplayName
            $result.LogicalName = $meta.LogicalName

        }

    }
    elseif ($TypeId -eq 14) {

        # Entity Key - was not wired to anything before this fix.

        if ($keyMetadataById.ContainsKey($ObjectId)) {

            $meta = $keyMetadataById[$ObjectId]

            $result.DisplayName = $meta.DisplayName
            $result.LogicalName = $meta.LogicalName

        }

    }
    elseif ($TypeId -eq 16) {

        if ($privilegeMetadataById.ContainsKey($ObjectId)) {

            $meta = $privilegeMetadataById[$ObjectId]

            $result.DisplayName = $meta.DisplayName
            $result.LogicalName = $meta.LogicalName

        }

    }
    elseif ($TypeId -eq 10) {

        if ($relationshipMetadataById.ContainsKey($ObjectId)) {

            $meta = $relationshipMetadataById[$ObjectId]

            $result.DisplayName = $meta.DisplayName
            $result.LogicalName = $meta.LogicalName

        }

    }
    elseif ($TypeId -eq 431) {

        # Attribute Image Configuration - BEST EFFORT. These configs are
        # 1:1 with a specific image attribute, so the objectid is assumed
        # to be that attribute's metadata id. NOT officially confirmed -
        # verify via the diagnostic dump.

        if ($attributeMetadataById.ContainsKey($ObjectId)) {

            $meta = $attributeMetadataById[$ObjectId]

            $result.DisplayName = $meta.DisplayName
            $result.LogicalName = $meta.LogicalName

        }

    }
    elseif ($TypeId -eq 432) {

        if ($entityMetadataById.ContainsKey($ObjectId)) {

            $meta = $entityMetadataById[$ObjectId]

            $result.DisplayName = $meta.DisplayName
            $result.LogicalName = $meta.LogicalName

        }

    }
    elseif ($componentEntityMap.ContainsKey($TypeName)) {

        if ($bulkLookup.ContainsKey($TypeName) -and
            $bulkLookup[$TypeName].ContainsKey($ObjectId)) {

            $found = $bulkLookup[$TypeName][$ObjectId]

            $result.DisplayName = $found.DisplayName
            $result.LogicalName = $found.LogicalName

        }

    }

}
catch {

    Write-Host "Failed resolving TypeId=$TypeId TypeName=$TypeName ObjectId=$ObjectId : $($_.Exception.Message)" `
        -ForegroundColor Red

}



$nameCache[$cacheKey] = $result


return $result


}

# --------------------------------------------------------------
# Build Output
# --------------------------------------------------------------

$rowCounter = 0

$output = foreach ($item in $results.CrmRecords) {

    $rowCounter++

    if ($rowCounter % 2000 -eq 0) {

        Write-Host "Processed $rowCounter / $($results.CrmRecords.Count) components..." `
            -ForegroundColor DarkCyan

    }

    $typeId = $null
    $typeName = $null


    if ($item.PSObject.Properties.Match('componenttype_Property').Count -gt 0 -and
        $item.componenttype_Property) {

        $typeId = Get-RawOptionSetInt $item.componenttype_Property

    }

    if ($null -eq $typeId) {
        $typeId = Get-CleanInt $item.componenttype

    }

    if ($null -eq $typeId -and
        ($item.componenttype -is [Microsoft.Xrm.Sdk.OptionSetValue])) {
        $typeId = Get-RawOptionSetInt $item.componenttype

    }

    if ($null -eq $typeId -and
        $null -ne $item.componenttype -and
        $componentTypeNameToId.ContainsKey($item.componenttype)) {

        $typeId = $componentTypeNameToId[$item.componenttype]

    }


    if ($null -ne $typeId) {

        if ($componentTypeMap.ContainsKey($typeId)) {

            $typeName = $componentTypeMap[$typeId]

        }
        else {
            $typeName = "Unknown ($typeId)"

        }

    }



    # Resolve name

    $details = Get-ComponentDetails `
        -TypeId $typeId `
        -TypeName $typeName `
        -ObjectId $item.objectid



    [PSCustomObject]@{


        SolutionName =
            $item.'sol.friendlyname'


        SolutionUniqueName =
            $item.'sol.uniquename'


        SolutionVersion =
            $item.'sol.version'


        SolutionStatus =
            if (
                $item.'sol.ismanaged' -eq $true -or
                $item.'sol.ismanaged' -eq "1"
            ) {
                "Managed"
            }
            else {
                "Unmanaged"
            }



        ComponentDisplayName =
            $details.DisplayName



        ComponentLogicalName =
            $details.LogicalName



        ComponentType =
            $typeName



        ComponentTypeId =
            $typeId



        ObjectId =
            $item.objectid



        SolutionComponentId =
            $item.solutioncomponentid

    }

}



# --------------------------------------------------------------
# Display Summary
# --------------------------------------------------------------

Write-Host ""
Write-Host "Solution Component Summary" `
    -ForegroundColor Yellow

Write-Host ""


$output |
    Group-Object SolutionName, SolutionStatus |
    Select-Object `
        @{N='Solution';E={$_.Group[0].SolutionName}},
        @{N='Status';E={$_.Group[0].SolutionStatus}},
        @{N='ComponentCount';E={$_.Count}} |
    Sort-Object Solution |
    Format-Table -AutoSize


# --------------------------------------------------------------
# Export CSV
# --------------------------------------------------------------

$OutputPath = "C:\Temp\SolutionComponents.csv"

$exportFolder = Split-Path $OutputPath

if (!(Test-Path $exportFolder)) {

    New-Item `
        -Path $exportFolder `
        -ItemType Directory `
        -Force |
        Out-Null

}


# Export details
$output |
    Export-Csv `
        -Path $OutputPath `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host ""
Write-Host "Full detail exported to:"
Write-Host $OutputPath `
    -ForegroundColor Green
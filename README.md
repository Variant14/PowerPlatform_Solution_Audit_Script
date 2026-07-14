# Dataverse Solution Component Inventory Script

## Overview

This PowerShell script inventories **Microsoft Dataverse solution components** and resolves:

- Component types
- Display names
- Logical names
- Metadata information where available

The script helps analyze solution contents by identifying components that exist within a Dataverse environment and provides better visibility during solution auditing and ALM processes.

---

# Change Summary

## Improvements Applied

The previous version had issues where some solution components were displayed as:

- `Unknown`
- Missing display names
- Incorrect component types

This version improves component type detection and name resolution reliability.

---

# Additional Component Support Added

The script now includes support for additional Dataverse solution component types:

| Component | Resolution Support |
|------------|-------------------|
| Mail Merge Template | Added |
| Team Template | Added |
| Entity Key | Added |
| Privilege | Added |
| Attribute Image Configuration | Added |
| Entity Image Configuration | Added |
| Entity Relationship | Added |

These components use Dataverse metadata and entity lookups where possible.

---

# Known Limitations

Some Dataverse solution components do not have standalone records or queryable metadata objects.

For these components, the script can correctly identify the **ComponentType**, but a **DisplayName** may not be available.

Examples:

- Ribbon Customization
- Ribbon Command
- Ribbon Rule
- Ribbon Diff
- Relationship sub-components
- Role Privileges
- Field Permissions
- SLA Items
- Routing Rule Items

---

# AI Component Limitation

The following Dataverse component types are valid:

| Component Type | Description |
|---------------|-------------|
| 400 | AI Project Type |
| 401 | AI Project |

However, the underlying Dataverse table/schema could not be confirmed through available public metadata documentation.

These components are intentionally not mapped to avoid incorrect entity lookups.

Diagnostic output can be used to identify the actual backing entity within a specific environment.

---

# Key Improvements

The updated script provides:

 Independent component type resolution  
 Protection against SCF metadata overriding known mappings  
 Support for newer Dataverse component types  
 Handling of large numeric component identifiers  
 Automatic resolution of more entity-backed components  
 More accurate ComponentType identification  
 Improved solution inventory reporting  

---

# Name Resolution Behavior

Display name resolution depends on whether the component has:

- A queryable Dataverse record
- Available metadata information
- A supported entity mapping

Components without an underlying record will still be identified by their correct component type, but may not contain a display name.

---

# Compatibility

Designed for:

- Microsoft Dataverse
- Power Platform Solutions
- Dynamics 365 environments
- Power Platform ALM auditing scenarios

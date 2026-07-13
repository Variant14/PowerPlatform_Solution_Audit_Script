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

// Relationship Management Functions
// 
// This file contains non-table functions that validate and manage relationships 
// between concepts, subjects, and sources in the academic archive system.
// 
// Functions in this file will:
// - Validate relationship integrity between concepts and subjects
// - Check for orphaned relationships (references to non-existent entities)
// - Validate strength values are within proper ranges (0-1)
// - Ensure composite keys are properly formed
// - Clean up invalid or duplicate relationships
// - Provide relationship health reports
// - Manage relationship type consistency (direct vs indirect)
// 
// These functions serve as business logic layer for relationship validation
// and maintenance, separate from the table structure definitions.

# Relationship Data Tables

This directory contains relationship tables that establish connections between different entities in the academic archive system. These tables enable the creation of a knowledge graph that links concepts, questions, answers, and source materials together.

## Overview

The relationship tables serve as junction tables that create many-to-many relationships between the main entities in the academic archive:
- **Concepts** (from `concept_details_table`)
- **Question-Answer Pairs** (from `question_answer_pairs_table`)
- **Source Materials** (from `source_material_table`)

## Table Descriptions

### 1. `concept_relationships_table.dart`
**Purpose**: Establishes relationships between different concepts/keywords in the knowledge base.

**Fields**:
- `concept` (FK): References the primary concept
- `related_concept` (FK): References the related concept
- `related_subject` (FK): Subject field of the related concept
- `relationship_type` (int): 
  - `1` = direct relationship (concept directly mentioned in related concept's article)
  - `2` = indirect relationship (loose relationship, not directly mentioned)
- `strength` (double): Relationship strength from 0 to 1
  - `0` = no relationship
  - `1` = synonymous/same term
  - Values between 0-1 indicate varying degrees of relationship strength

**Primary Key**: Composite key of `concept` and `related_concept`

**Use Case**: Enables concept-to-concept navigation and knowledge graph construction.

### 2. `question_answer_pair_relationships_table.dart`
**Purpose**: Links question-answer pairs to specific concepts and subjects.

**Fields**:
- `question_id` (FK): References the question_answer_pairs table
- `concept` (FK): References the concept_details table
- `subject` (FK): Subject field (extends from primary_subject via join)
- `strength` (double): Relationship strength from 0 to 1

**Primary Key**: Composite key of `question_id` and `concept`

**Use Case**: Enables filtering questions by concept, subject, or relationship strength.

### 3. `source_material_relationships_table.dart`
**Purpose**: Links source materials (references, citations) to concepts and subjects.

**Fields**:
- `source_material_id` (FK): References the source_material table
- `concept` (FK): References the concept_details table
- `subject` (FK): Subject field (extends from primary_subject via join)
- `strength` (double): Relationship strength from 0 to 1

**Primary Key**: Composite key of `source_material_id` and `concept`

**Use Case**: Enables finding relevant source materials for specific concepts or subjects.

### 4. `relationship_management.dart`
**Purpose**: Contains business logic functions for validating and managing relationships.

**Functions Include**:
- Relationship integrity validation
- Orphaned relationship detection
- Strength value validation (0-1 range)
- Composite key validation
- Duplicate relationship cleanup
- Relationship health reporting
- Relationship type consistency management

**Use Case**: Ensures data integrity and proper relationship maintenance across all relationship tables.

## Design Principles

1. **Normalized Structure**: All relationship tables use foreign keys to maintain referential integrity
2. **Strength Scoring**: All relationships include a strength value (0-1) to indicate relationship intensity
3. **Composite Keys**: Primary keys are composite to prevent duplicate relationships
4. **Subject Integration**: All tables include subject references for hierarchical organization
5. **Validation Layer**: Separate management functions ensure data integrity

## Usage in Quizzer

These relationship tables enable:
- **Intelligent Question Selection**: Questions can be filtered by concept relevance
- **Knowledge Graph Navigation**: Users can explore related concepts
- **Source Material Discovery**: Finding relevant references for concepts
- **Subject-Based Organization**: Hierarchical organization by academic subjects
- **Relationship Strength Filtering**: Prioritizing stronger relationships in search results
- **Data Integrity**: Automated validation and maintenance of relationship data

## Future Enhancements

- **Indirect Relationship Detection**: AI-powered discovery of loose relationships
- **Dynamic Strength Calculation**: Real-time relationship strength updates
- **Bidirectional Relationships**: Support for asymmetric relationship types
- **Temporal Relationships**: Time-based relationship tracking 
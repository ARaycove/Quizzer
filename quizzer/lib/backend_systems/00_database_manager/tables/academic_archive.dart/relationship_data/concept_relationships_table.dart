// The relationship table will record loose, and direct relationships between concepts
// A loose relationship means that the related concept was not directly mentioned in the concept article, but it is still related to that concept
// A direct relationship means that the concept was directly mentioned by another concepts article
// For the sake of efficiency Quizzer will initially gauge only direct relationships.
// Further iteration with the central Quizzer AI will be able to guage indirect relationship

// Table fields:
// | concept | related_concept | related_subject | relationship_type  | strength |
// | FK      | FK              | FK              | 1 / 2              | double   |

// Definitions:
// concept and related_concept are foreign keys to concept_details, this links the two together
// relationship_type 
//    - 1 == direct, 
//    - 2 == indirect
// strength: 
//    - float value from 0 to 1
//    - where 0 is no relationship
//    - 1 is synonymous/same term
//    - No value will be 1 or 0 directly since a value of 0 indicates no relationship, and 1 is the same term

// Primary key is a composite of concept and related_concept

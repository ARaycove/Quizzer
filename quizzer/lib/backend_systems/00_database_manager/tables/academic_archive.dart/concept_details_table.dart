// Concept Details table has a record for each concept/keyword, thus dubbed "concept". Some concepts have aliases, if a concept is an alias for another concept it will be still be included in this table

// Table fields are:
// concept | article | primary_subject |
// concept will be the keyword/term/name used by an academic field
// article will be a markdown string. It is a wiki article that defines and goes into depth describing the concept and it's relationships
// primary_subject defines the field/subject to which this concept belongs, for example "enculturation" is a concept used in Anthropology, and thus the primary_subject becomes anthropology.


// Will need the same CRUD operation functions as other table files do
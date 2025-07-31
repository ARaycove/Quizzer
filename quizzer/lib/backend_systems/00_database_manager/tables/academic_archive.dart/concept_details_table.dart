// Concept Details table has a record for each concept/keyword, thus dubbed "concept". Some concepts have aliases, if a concept is an alias for another concept it will be still be included in this table

// Table fields are:
// concept | article | primary_subject |
// concept will be the keyword/term/name used by an academic field
// article will be a markdown string. It is a wiki article that defines and goes into depth describing the concept and it's relationships
// primary_subject defines the field/subject to which this concept belongs, for example "enculturation" is a concept used in Anthropology, and thus the primary_subject becomes anthropology.


// Will need the same CRUD operation functions as other table files do





// Tying into the UI and making use of the actual table here
// We need to fill the table with data
// Panel will be split into two parts:
// TODO Enter initial concept (validating if it already exists)
// TODO Enter article's for concepts (meant to be extremely detailed)




// TODO provide a SessionManagerAPI that gets the article for a given concept

// TODO classification system, tie concepts to questions
// - TODO built out and train initial neural net
// - TODO HOW MANY LAYERS
// - TODO How big should the layers be?
// - TODO Should single output layer?
// - TODO Should activation function differ based on task_id? probably?

// - Design input size limitation
// - TODO input block for task_id
// - TODO input block for question_answer_pair
// - TODO input block for concept_id
// - TODO input block for concept_article
// - Design internal layers
// - How many layers?
// - Size of each layer?
// - 
// - Design output layer
// - activation function
// - dynamic activation function?
// - int or double output? probably always double then transform based on activation function. . .

// TODO provide a SessionManagerAPI that gets the concepts tied to a question

// Redesign Answer Explanation section:
// TODO For every concept involved, list it off
// TODO every concept listed will have an info icon
// TODO When the info icon is clicked, the concept article itself will appear as a popup for the user to read
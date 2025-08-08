// Not Implemented

// | subject_name | user_id | strength |

// subject_name links to subject name is subject details (foreign key)
// user_id is the user's id number
// strength is some double value representing how much they are interested in the subject. The number itself means nothing, but does represent a ranking of interest by subject and severity. So a strength of 1, with the highest being 2 represents nearly equal interest across the board, while a strength of 1, with a the highest being 1000 would represent an extreme lack of interest though not 0 interest.
// These values are used to calculate the ratio of questions accordingly

// the only subject names listed in here will be those in which question_id's are actually related, so we have 1886 total subjects in the taxonomy, if only 20 are referenced by question-subject relationships then only 20 will be listed here.
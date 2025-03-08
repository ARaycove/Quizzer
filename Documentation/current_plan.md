# Plans

## Record the start and stop time of each question answered:
Gather the time when the question is presented to the user
Gather the time the update score method is called
Get the difference between these times
Record that difference in a key-value pair
- current_date: <seconds to answer>(float)
- Having records of time required to answer, would allow us to feed data into a model trained to calculate "cognitive load"
### Lead into a system that optimizes speed of recall, not just accuracy
- Proposal:
    - Get average time to answer,
    - Determine an acceptable range around that average, (1 second for example, but we could experiment with this range) -> Or do a hard and fast above and below standard
    - If answered wrong
        - Enter status incorrect
    - Else:
        - If took longer than average AND correct
            - Enter status repeat
        - If within average range and correct
            - Enter status correct
        - If faster than average AND correct
            - Enter status correct
    In theory such a method would gradually reduce the average amount of time it takes to recall the correct answers.
- Thoughts:
    - If we enter status incorrect, we are penalizing users for not being fast enough, simply having the question repeat if correct but slow, serves to speed up recall, enforcing a standard
    - We can also set a minimum time limit, say if over 30 seconds, that would force a repeat, so if the average time is 45 seconds to answer we reduce this to 30 seconds, overriding the dynamic average threshold
    - Some sort of algorithm that keeps the average from rising signficantly.
        - Perhaps if a time is considered an outlier, not to include it in the average (for example if the user gets up from their machine and leaves the program open, the resulting time to answer would be well above the average and shouldn't be considered when determining what the average is)


## More stat records
### Date: num_questions_due
This would be a list of key value pairs, where we record the amount of questions due by date. To better inform the user of the upcoming schedule to keep up with

### Record What the user knows by subjects
- Go into the user profile and get a record of how many questions the user knows for every subject
- This would be stored in key:value pairs
- Displayed on Screen as a graph or table (or both?)

### Record What the user knows by concept
- Based on the related tags, record a list of concepts that the user is currently familiar with
- Concepts are numerous, so bar chart is not practical
- Perhaps show as a table, or circular chart


## Small AI Models

### Classifier for Concepts
Use large LLM's that currently exist to estimate what concepts exist:
- Because the number of concepts and terms currently in existent is far too large to manually scrub
- Concepts and Terms change over time, the definitions change over time too, as well as their connotations (connonative and denonative definitions need to be taken into account)

### Classifier for Subject Matters
- Manually scrub for all formal subject matters and fields of study
- Place these in a list/array
- Train a model to match a question-object with fields in that array

### Classifier for New-User Knowledge
- Note: Modules will only be used as a "kick-start" mechanism for new users
    - However module system will be obsolete once AI classifiers are implemented properly
- A new user would select a desired field of study and identify what concepts they are:
    - Interested in
    - Already are familiar with
Once the user has been assessed the larger model would take over in guiding the learning process

### Classifier for relational map of concepts
- Development of this model is not useful until classifiers to identify subject and concept are made.
- One of two options:
    - Implement a mind-map feature (which is extremely useful as a study technique) that grabs a random concept the user is familiar with and have them identify what concepts are related based on what they are able to immediately recall around that concept, the mapping exercise would then repeat for recalled concepts (what do those recalled concepts lead you to recall). It's a recursive exercise
        - If given a large enough user base doing mind-map exercises, the users of Quizzer will generate the relational graph of concepts based on real people.
    - Attempt to train a model to identify and do mind-map exercises to tie concepts together (I am strongly opposed to this idea, since AI not humans would map concepts, thus it turns into a proxy for the real thing)
        - Downside is a major risk that the generated map of concepts might not reflect what real people actually link together.
        - This ties into the idea of bias in algorithms, and the general principle that AI should be avoided in system critical applications. I would deem the real mapping of concepts to be a system critical application. And if need be I, the developer of Quizzer, will manually do the mind-map exercises until such a time that users consistently do them with me.

### Built-IN Question Object Generator
- Model would take source material as input
- Would then generate the question and answer pair
    - Would be trained to produce image, audio, and video style questions
- Output question-object would feed into a verification model
    - verification model would decide whether the question is coherent or not
    - Can the question be answered without having just read the source material on which it was derived.
    - Is the question is an appropriate format? etc.
- If object is valid, would then feed to the classifiers
- Once the classifiers are done, we would add the question object to the database
(legally, everything is AI generated right?)

For initial development:
- 

## Upvote-Downvote
- Popular vote, allow users to downvote questions to be removed from Quizzer's database
    - If a user downvotes a question, it would be excluded from their profile, just for that user
- Also allow users to upvote questions they like.
- Threshold needs to be determined to figure when a question should actually be removed from Quizzer's database.
System would provide training data to use on developing the above proposed models

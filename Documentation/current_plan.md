# Plans

## Record the start and stop time of each question answered:
Gather the time when the question is presented to the user
Gather the time the update score method is called
Get the difference between these times
Record that difference in a key-value pair
- current_date: <seconds to answer>(float)
- Having records of time required to answer, would allow us to feed data into a model trained to calculate "cognitive load"
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



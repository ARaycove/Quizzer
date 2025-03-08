# 10-07-24
fix the building of the revision_streak_stats, so it sorts the dictionaries keys in numerical order
- pulled raw data, changed data type to a list, manually rebuilt the data, by inserting items in the desired order
- create a sources property to question objects, here will be information on where the answer came from. Academic sources
    - All question objection now have academic_sources key value pair where the value is a list. Intended use is to insert individual citations into the list.

# 02-24-25
Completed the following plan:

## Adjustment for confidence
### Allow user to answer correctly with high or low confidence
- Could repurpose the skip button to low confidence correct 
    - Skip button currently just fetches a new question and does nothing with the object
- If low confidence
    - Do not increment or decrement the revision streak score
    - Set the due date to immediately
- If High confidence
    - Increment as normal
Actual implementation was to turn the skip button into a "repeat" button, that sets the current due date to time.now() for immediate revision, this increments the total answered metric by one, does nothing else.

### Intent
- Allow the user to restore 100% confidence in answer without punishing or rewarding them. 
- Serves as a training mechanism
- 

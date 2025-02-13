# Adjustment for confidence
# Allow user to answer correctly with high or low confidence


- Could repurpose the skip button to low confidence correct 
    - Skip button currently just fetches a new question and does nothing with the object
- If low confidence
    - Do not increment or decrement the revision streak score
    - Set the due date to immediately
- If High confidence
    - Increment as normal

# Intent
- Allow the user to restore 100% confidence in answer without punishing or rewarding them. 
- Serves as a training mechanism
- 

Surprising how easy it is to make changes to functionality when the whole thing is well structured

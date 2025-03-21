"""
Question Classifier Module

I tried to use AI to help me build an advanced classifier, it failed miserably and I wasted two days on garbage code,
Though I did end up manually typing out an entire academic discipline taxonomy for future use:
"""
# The Plan for this
# Using the subject taxonomy written out in the subject_generator, we will import an existing LLM from huggingface for local use, we will install and store it locally so we can distribute it with the platform. 


# Import and setup a very simple use case

# Develop an initial round of prompts and test output.

# Once we verify the model is properly loaded and gets the prompt correctly. Draft a prompt that asks to classify the QuestionObject using the provided taxonomy

# Hope and pray the AI model we get can actually do this, Asking Claude to build this for me got some rudimentary bullshit that didn't even bother prompting the damn model to start with. I wasn't aware how fucking wrong it was. So now we have a better plan for how to build this out.

# Once we get a good framework for this thing, we can use the same model to turn around and classify questions by concept label


# Rambling thoughts:
# Using PCA and K-Means or Hierarchical clustering we'll organize everything using a raster plot. Though much study is needed to properly understand how that actually works. This method would remove the need to manually classify by concept and subject. Turning subject and concept into semantic labels we can place over what's classified. Subject and Concept is how humans organize knowledge presently and serve as a good guage of interest. Giving users a subject to say they are interested in or not is easier than group K-4, does that interest you? What about group K-21?

# Once K groups are classified we can fetch all the questions that fell in that cluster and manually see what subject that is, if it fits in an existing subject at all. I estimate that the current classification of knowledge is too siloed and doesn't actually reflect real knowledge.
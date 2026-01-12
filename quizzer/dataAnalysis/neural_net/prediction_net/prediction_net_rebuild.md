We are given a large dataset of question attempts, spanning 1400+ features covering everything from the vectorized form of the question, meta data about the question, the user's history with the individual question, overall history with all questions (usage stats), their profile data, how the question relates to other topics, the user's history with all topics, and other data that can be collected through the platform. We collect as much data as we can for every attempt made, the problem is then which features to use to create a binary classification neural net that attempts to predict whether the user will get a question (1) correct or (0) incorrect.

Best subset selection,
We are given that the records in this dataset are missing values, has been built incrementally, so as new features are added older records contain nulls for those values, and further certain collection methods are not able to collect the full feature set if the data  is collected off the platform.

So we need to train a singular model on all data, regardless of if a specific record is missing data or not.

Potential solutions:
1) Parse out the records based on which set of features the records contain. If a record contains features 1-50, and 51-100, then we train a model on only those features. This would place records into groups. row by row in the table. Depending on the collection over time, we could get many many groups of questions. and combinations of subsets. However this one appears to result in the least amount of data loss.
	1) We could however end up with groups of records where only 1 or 2 records exist in that group. Based on the data, if most records end up in their own atomic silos we will have to rethink this approach. Otherwise in most records fall in just a few subsets (collection has been fairly consistent) we can train models for each subset of the dataset. Each model would learn that subset, then concatenating those gives us a final model.
2) Parse out the records on a complete feature basis, If Features f_1, f_2 . . . f_k have a complete set of values then separate these out, splitting the records into two. With a record containing the complete set in one dataframe, and the remaining values in that record kept in a second dataframe. In this way we preserve the sparse data while extracting the primary dataset into a smaller dataset that has no missing nulls. Train a model on this complete dataset. Once trained, clean the remaining dataframe of any records where no data is left in them, and repeat.
	1) If a dataframe contains features where each feature has at least one missing value, we get a situation where there is no complete dataset. We can either train models on one feature each (getting potentially a large number of models), or accept the efficiency gain of dropping data.
3) Stop concerning ourselves with missing values, run random subset selection directly. Given $\{f_1, f_2 \dots f_n\}$, 
	1) select first $f_1$ + k other random features, where $k$ will be a hyper-parameter in a grid search. This will give us a random subset of features,
	2) Pull all records in the dataset that have all of the features in the subset selected. If there are no records that contain all of these values, repeat 1) until we find a subset that will give us a complete dataset with no nulls.
	3) Train a model on this subset
	4) iterate to $f_k + 1$
	5) concatenate the two models, and train concatenated model on all records that contain all records in the two models, which will return one model, if the concat-model does better than the previous, keep it, else retain the previous model. (In theory if multiple models share an input, we should only need to input it once, and that one input neuron will map to multiple models, so redundancy here should be fine)
	6) This will give us $n$ models precisely to train. which could be a-lot, but each one will be very small, so quick to train individually, regardless given the large feature set, this approach will take a very long time, but should give superior results. Additionally this ensures that all features get incorporated into the model.

Both Options 1 and 2 give us the side effect that the final model will only be able to be fine tuned on a small fraction of the dataset (records that have the complete feature set). To resolve this we would to think of an approach where our model M_1 is trained on the smallest subset, fine tuned on all records where those features exist. M_2 is trained and fine-tuned in the same way, When M_1 + M_2 is made we train the hybrid model on all records containing all datapoints. When M_3 is made it is trained on just its subset, then (M_1 + M_2) + M_3 is fine-tuned on data containing all features that exist across all 3. At each phase some data is used multiple times to fine tune. This solves the problem but introduces overfitting potentials. However (M_1 + M_2) + M_3 is trained (M_1 through M_3) weights are frozen, only the concat layer is trained and tuned. We don't have to keep this model if it does worse as a result of this process, but it would allow us to sequentially add new models and fine tune again and again. Giving us a nice ensemble.

Option 3 should work nicely, and regardless the sparse final model isn't as much of an issue, since if the new data doesn't increase performance it won't be included anyway. This option however we need to ensure the input layer shares neuron mappings instead of duplicating input neurons, if $f_k$ is an input in 10 of the sub-models embedded within there should not be 10 input neurons that $f_k$ must feed into, it should only be 1, and that one neuron should map to the ten neurons in the network.

# Subset selection
Regardless of the feature set to pick from we run best subset selection methods, select a random subset of the total features for this model, and train the model sequentially on that subset, then the next subset, then the next, concatenating each model together.

**Process:**
We first train the initial model $M_1$ with some input neurons that map to feature inputs,
We then train $M_2$, freezing the weights of $M_1$ and $M_2$ 
We then construct a Concatenate model $C_1$ which takes in $M_1$ and $M_2$, add a small Concat hidden layer and make that trainable, while $M_1$ and $M_2$ weights are frozen. Training $C_1$. Since the input to the new hidden layer is just 2, we can make a hyperparameter for this concat_layer_size -> CLS. And let the grid search figure out what size layer is best, my personal heuristic says 3 neurons is likely good. but could be anywhere from 1 - 10. Alternatively we could just setup this so that we test 2 - 5 neurons on each concatenation. embedding the grid search internally. Thus we can make CLS be a list of integers to try.

$M_3$ is then trained,
$C_2$ is then trained using $C_1$ and $M_3$ 

Evaluating the performance of $C_2$ against $C_1$ we retain the one that performs better. 

Repeating this process $C_k + 1$ = $C_k$ + $M_n$ 

STOP CONDITION: When the model fails to see improvement over the last N training rounds, where N will be a hyperparameter, we should try 5 models trained and added without improvement, 10, 15, 20, and 25.

_____________________
### Thoughts:
I think option 3 would serve the best, not every subset model will work out, and this method seems very similar to boosting. In this case we are boosting by iteratively building a neural network each succession being trained on the residuals of the previous. Stopping the process once the model converges. This potentially gives us what amounts to a large model, if our subset size is 10 each, and even just 10% give improvement thats 140 models incorporated each with 10 inputs, let's say they each were given 5 hidden layers. Well now that I do the math, it wouldn't be much more than 1000 - 2000 neurons in length, which is a very small network indeed.

__________________
The day after:
Some pseudocode to describe the process
```python
def build_concat_model(working_model, sm):
    pass # Ensure when building the concat model to record the input layer, so we can use it for inference later.

def select_best_model(evaluation_list):
    '''
    On each training round, for each feature we only select one random subset that uses that feature, not multiple sub_models to include that feature.
    The iterative process ensures that if the feature isn't useful it won't get included
    It also ensures that the model does not grow too large. The largest the model can be is len(all_features) number of sub-models.
    '''
    pass # Should include the working model itself, as the working model may not have shown any improvement in the training iteration.

df = pre_process_training_data()
all_features = collect_feature_list(df)
# Shuffle the features based on seed:
random.shuffle(all_features)
n = 5 # the number of random feature subsets to select from

working_model = None
evaluation_list = []

for i in all_features:
    subsets = select_random_feature_subsets(i, n)
    sub_models = []

    for s in subsets:
        # Train our sub-models
        sub_model = train_sub_model(df, s) # include grid search in the train functions. getting the best possible model from this subset, this can be sent off to separate process for memory management
        sub_models.append(sub_model)

    if working_model == None:
        working_model = select_best_subset_model(sub_models)
    else:
        for sm in sub_models:
            cm = build_concat_model(working_model, sm) # build a concat model for every sub_model.
            evaluation_list.append(cm)

        evaluation_list.append(working_model) # Add the working model to the evaluation_list
        working_model = select_best_model(evaluation_list)

    # At this phase the working model has been updated and we iterate to the next feature in the dataset
    evaluation_list = [] # reset the evaluation list for next round
    sub_models      = [] # reset the list of sub_models
    gc.collect() # run the garbage collector since models take up a good amount of memory space


# Considerations:
# 1. Ensure that each sub-model performance is recorded for post-analysis, and presentation
```
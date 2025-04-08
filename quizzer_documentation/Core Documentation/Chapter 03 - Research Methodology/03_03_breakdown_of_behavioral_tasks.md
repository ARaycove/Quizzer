Each Task will be responsible for producing a single row of data. Some of these tasks are extremely labor intensive, and thus we do not conceive of a scenario where it is reasonable to ask a participant to complete the entire task in one-shot. For this reason, each task will be broken down into multiple sub-tasks. Each sub-task will serve a similar to role as those machines in an assembly line, producing just one component of the entire task. This also allows for tasks to be started and stopped mid-way through complete. For example if a task has three parts (p1, p2, and p3) p1 could be completed by one person. The next person could produce p2, then tomorrow perhaps a third person could complete p3. This structure eliminates any time sensitivity involved in the completion of a single task.

Some of these tasks are strictly like classifying data, or archiving existing data. Other tasks listed in this chapter are more related to traditional behavioral tasks. A simple task is presented and the user is to respond, and the results recorded. The archival, generative, and classification tasks will be described first, and the traditional behavioral tasks will be described second.


-----------------------------------------------------------------------------------------------------------
# Task_03: Usage data,

# Other Considerations for data to incorporate for analysis
The concerns with this project quickly meander into problems with privacy and data security. So much of the data we could collect may or may not be ethical to acquire. For this reason, the base approach I am taking is to prompt users to sync data from platforms that have already collected their data. Then using that personal data, we can match it up against the time_stamps recorded when questions were answered. The result should be a very detailed record of the state of the user at that moment in time. Which allows us to have comprehensive data for training a neural network to predict when the user is most likely to begin forgetting the information presented to them.

My general philosophy is to collect as much data for analysis as possible, as ethically as possible. For many data points I would hypothesis they would have little to no effect on the prediction. Such as location data, which doesn't make logical sense to have an impact on memory retention.
## Sync health data with Quizzer
- Health data recorded from other applications like Samsung Health could be entered into Quizzer to provide additional possible variables that might be at play in predicting memory retention. This would include sleep data, step counts, activity levels, heart rate, blood pressure, diet, and other health metrics. Since the brain is biological it by extension is effected by your overall health.

## Interest Inventory and Psychological Profile Tests
While Psychology test can be seen as gimmicks, it might still be valuable information for analysis, understanding how a user's perceived psychological profile effects their learning abilities.
Examples of pre-existing profiles:
- Myers Brigg
- Autism Assessments
- STRONG inventory

## Location data
- My hypothesis is that locational data has little to no correlation with user performance, collecting this data for analysis should either confirm or deny this assertion. If my hypothesis is correct then locational data collection would be removed from the platform otherwise it would be retained. There are arguments for or against this hypothesis. For example it shouldn't matter which rural town in America you live, but if you reside in an area that is oppressive, conducts human rights violations, or other such tactics, this would very much effect memory retention. However it's unlikely that victims in those areas would be using this software to begin with.

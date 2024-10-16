Next Features
1. Add question inside GUI (store questions in reserve bank)
	1. Questions added go into a reserve bank
2. View question list(master list or [[Quizzer Reserve Bank|reserve bank]]) inside GUI
	1. Option to transfer to reserve bank(change value of in_circulation) or delete question
	2. Option to transfer from reserve bank to master list (though not recommended)
6. Once cognitive load tracking is implemented we can dynamically set the amount of questions in circulation based on the individual's capacity for learning. (some can only handle a few questions a day, some in the hundreds)
________________________________________________________________

# Stats Feed
1. Provide visual graphs of the users statistics as well as a standard text feed


# Customizability
Users do not get a say in the selection algorithm, the algorithm design is to be scientific in nature and is developed very carefully to reflect the science of learning.
The scoring algorithm is also pre-determined the user will not be able to self-score themselves as this defeats the purpose of research based algorithms.

# Community
Sync Functionality
	MVP Iteration 2 will be able to export and upload a packaged CSV file compatible with the program.
	Users would then be able to share their QA pairs with other users, enhancing the experience.
# Difficulty or Level System
Would assess a hierarchy of concepts and place questions in tiers. only when the user is able to consistently answer questions in a tier would they be presented with higher level questions.
	Concepts to consider when building this system:
	1. Hierarchy of concepts:
		1. Concept Dependency Tree/Graph: Create a dependency tree where nodes are concepts, and edges denote dependency. For example, basic algebra might be a prerequisite for calculus, which might be a prerequisite for differential equations, etc. This tree can guide the flow of questions.
		2. Concept tagging: Each question in your system should be tagged with one or more concepts it relates to:
	2. Initial Assessment
		1. When a user first begins using the system, assess their current knowledge level through a series of questions spanning various concepts.
		2. This can be a quick diagnostic test to place them at the right level in your concept dependency tree.
	3. Adaptive Learning Algorithm
		1. Based on performance in the initial assessment and subsequent questions, adjust the difficulty and topic of the next questions.
		2. If a user struggles with questions related to a particular concept, revisit foundational topics.
		3. As users prove mastery over certain concepts (e.g. by consistently answering related questions correctly), move them up to more advanced topics.
	4. Spacing and Repetition
	5. Feedback and Recommendations
		1. After each session or set of questions, provide feedback on performance, areas of strength, and areas that need improvement.
		2. Offer resources or lessons on concepts users struggled with. This can be readings, videos, or practice problems.
	6. Dynamic Question Generation:
		1. If possible, design a system where questions are dynamically generated based on the topic. This ensures users don't just memorize answers but understand the concept.
		2. This is more feasible for some subjects (e.g. mathematics) than others.
	7. User Profiles and Learning Paths:
		1. Maintain a user profile that tracks performance, mastery over concepts, and learning pace.
		2. Based on this, create a personalized learning path. For instance, if a user has mastered basic algebra but struggles with geometry, their learning path might prioritize strengthening geometry fundamentals.
	8. Peer Learning and Collaboration:
		1. Introduce a feature where users can discuss or collaborate on challenging concepts or questions. Peer explanations can sometimes be more accessible and relatable.
		2. However ensure measures to prevent direct sharing of answers which would defeat the purpose of the system.
# Question Generation
## AI Generation (Option 1)
- Have AI read notes and generate question answer pairs based on them
	- This sounds cool, but after further thought seems more like a gimmick.
	- A better strategy might be having AI read notes to see what the user is currently studying then use that information to pull questions from a community generated database of question answer pairs.
## Community Generation (Option 2)
- Perhaps a better way than trying to get a machine to understand language, we have the community share and rank question answer pairs.
- Some of this data already exists publicly (Quora, trivia sites, educational sites, etc.)
# Scoring Algorithm
Quizzer needs an **answer determination system** to be truly effective at an institutional level
	- The ideal system would use Natural Language processing and machine learning and large datasets to determine accurately if questions are answered correctly. Though the use of LLM's Large Language Models may prove to augment this.
	- Peer Evaluation could also play a factor into the machine learning process, by having experts determine the validity of the machines decisions, the machine will make more intelligent decisions.
	- We can also use user data to train the models.
- A Timer should be implemented as part of cognitive load tracking, a very quick answer to a question is an indication of mastery, so such questions should be spaced further apart. (Don't need to review these as often)
# Selection Algorithm
1. This algorithm decides what is displayed to the user and when
2. Base algorithm sorts every QA pair by due date and picks a set off the top
	1. for perceived randomness
	2. for subject focused study
3. settings allow the user to the choose which subjects have priority over others. So that in an academic setting, a user can focus the program on whichever subjects they are actively studying while leaving subjects they aren't actively studying on the back burner.
4. This priority setting also comes into play when deciding which questions to place in circulation and which ones to pull out of circulation.
5. 
# User Assessment
## Measuring Cognitive Load
1. Measure the user's cognitive capacity
	1. (Could ask the user on a scale how much they experienced, periodically throughout the program)
	2. how much mental effort did you invest in solving this problem?
	3. A more objective way of measuring cognitive load is the use of secondary-task procedures, in which the amount of load imposed by the primary (learning) task is measured by the performance or response time on a secondary task: the higher the load imposed by the primary task, the less cognitive capacity is available for attending to the secondary task, and as a consequence, response to the secondary task will be hampered/slower (for a review, see Brünken et al. [2003](https://link.springer.com/referenceworkentry/10.1007/978-1-4419-1428-6_412#ref-CR2_412 "Brünken, R., Plass, J. L., & Leutner, D. (2003). Direct measurement of cognitive load in multimedia learning. Educational Psychologist, 38, 53–61.")). For example, learners could be asked to respond to a color change of a letter placed above the multimedia materials they are studying as soon as possible (see Brünken et al. [2003](https://link.springer.com/referenceworkentry/10.1007/978-1-4419-1428-6_412#ref-CR2_412 "Brünken, R., Plass, J. L., & Leutner, D. (2003). Direct measurement of cognitive load in multimedia learning. Educational Psychologist, 38, 53–61.")). The slower their response to the color change, the more cognitive capacity was being devoted at that moment to the multimedia materials. Note that in order for the secondary task to be sensitive to variations in cognitive load, it should draw on the same working memory resources as the primary task. Moreover, if learners decide to devote more cognitive capacity to the secondary task, this might hamper their performance on the primary (learning) task (Brünken et al. [2003](https://link.springer.com/referenceworkentry/10.1007/978-1-4419-1428-6_412#ref-CR2_412 "Brünken, R., Plass, J. L., & Leutner, D. (2003). Direct measurement of cognitive load in multimedia learning. Educational Psychologist, 38, 53–61.")).
	4. with increases in cognitive load being associated with increases in dilation (maybe use the devices camera and detect pupil dilation (this wouldn't be stored, but it would be a non-intrusive measure))
	5. Measure load by the speed in which a question is answered? (use 0sec as minimum and the users maximum time spent answering a question as the other end of the scale. Use this scale to rank speed on a scale of 1 - 10)
2. Measure load on a scatter plot
	1. x-axis -> revision streak
	2. y-axis -> cognitive load score
3. get a cognitive load score for each question
4. The algorithm would then be able to determine an equal mix of questions between those with low and high cognitive load.
5. The idea stands that the we don't want to overwhelm the user with nothing but high cognitive load questions, effectively mixing in easier less demanding questions in with those that require more thought.
6. Ranking cognitive load also allows that variable to be included in with the question generation so that the AI does not produce overly demanding questions. (Though I suspect the data will be inconclusive in that what is demanding for one person will be effortless for another. So even the question generation algo needs to tailor to the user, rather than a master list.)
7. Effectively if we can teach a complex topic with a large volume of easy questions, the topics will be easier and more enjoyable to learn.
8. Attempt to track total capacity for cognitive load against the demand of each question.
	1. regeneration of mental energy is a factor that must be considered.
9. Time can be considered a factor is determining how cognitively demanding a question is.

If we are able to get a measurement by question of cognitive load,
then we compare that to the average number of questions a user answers per day
We can multiply the average number by the average cognitive load score of those questions. Thus getting a total cognitive load capacity tailored to the user.
## Assess user capacity for daily question load
- How many questions per day will this user be able to answer on a daily basis?
- This gives an integer value
- Store questions in an "inactive" reserve pool of questions
- Pull questions from the reserve pool until User daily questions == avg questions shown per day (which is already assessed)
- Pull questions out of circulation should the the avg questions shown per day (AQSPD) value rises above the User daily questions. Assess an appropriate margin for this task as to prevent an infinite loop
## Assess user field of study
- Using the user's notes we should be able to easily detect what the user is focused on.
- By having a community question pool, we could build an assessment test for any given subject.
- USER OPTION: pick field of study interest to tell the algorithm what to focus on and what not to focus on. (Interested / Not Interested)
# User Interface
GUI will have a manage questions section that allows the user to add, delete, and edit the current list of questions that Quizzer pulls from.
1. Self - Scoring is largely appropriate and is used widely in economics.
	1. therefore no complex answer determination system is required to make this effective.
2. pop-up prompt versus static rating for cognitive load self scoring. A/B test?

____________

# Future Plans
Quizzer should have an online database that houses a master list of question and answer pairs to be curated by professors and experts in each field. This would require a lot of collaboration but would remove the responsibility of the user to input their own study questions and instead be able to add questions from a curated list based on where they are currently at in their studies.

If this curation is based on user data, it would remove the legal concern of plagiarism.

Implementing a selection of curated questions and answers would significantly reduce the processing power needed for the **answer determination system**. The goal would be to cooperate with professors on campus to ensure we collect an exhaustive study system for use by future students across the globe, not just a specific university.

# Sources
https://link.springer.com/referenceworkentry/10.1007/978-1-4419-1428-6_412
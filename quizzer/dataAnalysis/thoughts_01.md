# Topic Modeling and LDA
Using a LLM or some similar transformer we can plot a large corpus of information in an embedding space. This however results in low resolution for points within a cluster. LDA can be used also for topic model and provides a higher resolution but with a lower scale.

The proposed process then is to first run a transformer and large scale low resolution topic modeling approach to get a high level picture of the data. With this we can extract specific topic groups, currently the topic model is able to separate broader fields but struggles with sub-topic classification to some extent. For clustering we propose a GMM gaussian mixture model to find these topic clusters, this will result in overlapping topic clusters to share datapoints. That is a data point can belong to multiple clusters at once. Then for each topic cluster we run a LDA to get a high resolution picture of the embedding space within the cluster. Once we have a high resolution plot of the data, we can collapse the embedding space into a graph, where each data point is a node, and the distance between two points becomes an edge with associated cost value. We draw an edge if the data point is within a certain distance which is based on the maximum distance at which knowledge of that point is predictive of the surrounding space. Since the edge is not meaningful we do not draw it. Once we have our graph structure, we store it aside. After repeating this process for all clusters we merge all graph structures together into one large graph. This may result in orphaned data points, but this will indicate that the content in the database is incomplete and will provide clues on what information needs to be presented next.

This process could become recursive, if a within cluster LDA analysis reveals that the points are so dense within it we can re-run the clustering model on that cluster again to get small enough clusters where the data is meaningful enough for LDA to provide a high resolution picture. If all goes well and as intended we should have a complete graph where each node is a question or some other "unit of knowledge", and every edge shows how far apart two nodes are, ignoring all edges that are too far apart to be considered meaningful.

In order to address to knowledge dependencies, that is "what is required to be learned in order to allow for the learning of other concepts?" we can understand an example where in order to explain how multiplication works one first must have an understanding of basic number theory, and with it base 10 number systems which is most common, and further the basics of addition which rely on the former two. In feature space however this dependency is not immediately clear. I propose we preserve the granular clusters derived from forming the graph structure in the embedding space. Using this structure we can derive which clusters are connected and which ones are not, likely using the centroid of that cluster and comparing the centroids of all clusters to get a very high level overlay of the entire structure. We assign each node with its topic label. In the application we keep track of how well the user has mastered each respective topic, by getting an estimate of how well the user understands in whole the questions inside that topic. We can use this data now to study how mastery of one topic effects the ability to master another topic zone. We expect to find that some topic clusters are impossible to learn if the user has not mastered certain topics first. We end with a structure that shows the directional dependencies between topics, which can then be navigated to guide initial onboarding assessments.

This graph structure then gets returned to the main application database, where other algorithms can be deployed in order to traverse and navigate the knowledge map.

Below is the data structure one can expect in a question record;
{0: 
    {
    'question_id': '2025-05-04T12:44:56.594619_7465dce6-abcf-4963-92a1-30dd7118c23a', 
    'time_stamp': '2025-05-04T12:44:56.594619',
    'citation': None,
    'question_elements': [{'type': 'text', 'content': 'Select all the ODD numbers.'}],
    'answer_elements': [{'type': 'text', 'content': 'Odd numbers are not divisible by 2.'}], 
    'concepts': None, 
    'subjects': None, 
    'module_name': 'is even or odd', 
    'question_type': 'select_all_that_apply', 
    'options': [{'type': 'text', 'content': '17'}, {'type': 'text', 'content': '50'}, {'type': 'text', 'content': '23'}, {'type': 'text', 'content': '41'}, {'type': 'text', 'content': '49'}, {'type': 'text', 'content': '7'}], 
    'correct_option_index': None, 'correct_order': None, 
    'index_options_that_apply': '[0,2,3,4,5]', 
    'qst_contrib': '7465dce6-abcf-4963-92a1-30dd7118c23a', 
    'ans_contrib': '', 
    'qst_reviewer': '', 
    'has_been_reviewed': 0, 
    'ans_flagged': 0, 
    'flag_for_removal': 0, 
    'completed': 1,
    'last_modified_timestamp': '2025-05-07T15:53:16.433060Z', 
    'has_media': None, 
    'answers_to_blanks': None
    }
}
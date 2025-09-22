# Data Structures:
## Question Data
The actual question itself
## User_Question Data
Performance metrics
## $\vec{I}$ Interest Data
Let $\vec{I}$ be the data points representing the user's relative interest level with any subject where:
$s$ = "subject_label", such as biology, computer science, statistics, etc.
$v$ = relative value $[0, 1]$ representing the level of user interest in any given subject relative to other interests. We can determine this value through a survey in the form of given $s_1$ and $s_2$ which are you more curious about.
$I_n$ = $(s, v)$

For each subject a value is given, sorting these points from highest to lowest will order interests accordingly

# Question Selection Algorithm
After a user answers a question and submits a response, which question in the database should be presented next?

Let $Q$ be the set of all questions in the Quizzer database
We divide out $Q$ based on whether it is in the user's profile or not in the user's profile

Let $U$ be the subset of $Q$ that have been introduced to the user by Quizzer
Let $X$ be the subset of $Q$ that have NOT been introduced to the user by Quizzer

Let $\vec{T}$ be the temporal component
Let lowercase $\alpha$ characters be the individual components such as $q$, $t$, $u$, $x$, etc.

Let $p$ be the probability that $Q_n$ will be answered correctly
Let $q$ be a member of $Q$
Let $t$ be a number in days in $\vec{T}$ 
Let $x$ be a member of $X$
Let $u$ be a member of $U$
Let $d$ be the projected due date of $u$

Let $P$ be a binary prediction classifier function that maps question features to probability of correctness, $P: Q \cdot T \rightarrow [0,1] \rightarrow p$

When a user answers a question $U_n$ deemed $u$, using model $P$ we will draw the probability curve for $u$, until such point where the projected $p$ drops to $p < 90\%$. We will feed $u \cdot \vec{T}$ into $P$ at increments of $t$ hours, similar to learning rate in a gradient descent equation, we will increase $t$ based on the derivative of the curve as we draw it. The smaller the slope of our curve the greater $t$ should be. This will set $d$, at which point at day $d$ we will redraw the forgetting curve again if $p >= 90\%$. Else if $p < 90\%$ we will not project $d$ again

Let set $A$ be the subset of $U$ where $\{U_n \in U : d_n \leq \text{time.now()}\}$ 
Let set $B$ be the subset of $U$ where $\{U_n \in U : d_n > \text{time.now()}\}$. 
Thus $|A| + |B| = |U|$ 

We then pick $u \in A$.

Out of $A$, we will based on user interest decide what out of that set will be selected. Weighting by subject interest ratio provided by the user. 

If $|B| = |U|$ AND $|A| = 0$ then the selection algorithm will perform exploration on $X$

Let $X_1$ = $X$ where $0 < p <= 0.5$ 
Let $X_2$ = $X$ where $0.5 < p <= 0.8$
Let $X_3$ = $X$ where $0.8 < p <= 1$

If $|X| = 0$ return no question, and provide a message to the user indicating there is nothing left to learn

We will select first a question from $X_2$, 
if $|X_2| = 0$, then select from $X_1$, 
if $|X_1| = 0$, then select from $X_3$.

When selecting from $X_n$ we will decide based on the $\vec{I}$, maintaining a ratio of subject matters as provided by the user. every $u$ has an array of $s$ to which it is associated.
## Selection Algorithm
We will train a new model $M$ that drives the selection algorithm, we will occassionally prompt the user asking, "Was this question too easy, somewhat easy, just right, kind of difficult, or too difficult". This is a variation of them [[multi-armed bandit problem]].



However the existing solution is as follows
## Selection Scoring Formula

For each question $u \in A$, we calculate a selection score $S(u)$ using:

Let $w_I = 0.4$ (subject interest weight)
Let $w_R = 0.3$ (revision streak weight)  
Let $w_T = 0.3$ (time overdue weight)
Let $b = 0.01$ (bias term)

For question $u$ with:
- $r_u$ = revision streak count
- $t_u$ = days overdue from due date $d_u$
- $I_u$ = highest interest value among subjects associated with $u$

We normalize these values:
- $\hat{r}_u = \frac{1}{\max(r_u, 1)}$ (normalized streak, inverted so lower streaks get higher priority)
- $\hat{t}_u = \frac{t_u}{\max_{v \in A} t_v}$ (normalized time overdue)
- $\hat{I}_u = \frac{I_u}{\max_{v \in \vec{I}} v}$ (normalized interest)

The selection score is:
$$S(u) = w_I \cdot \hat{I}_u + w_R \cdot \hat{r}_u + w_T \cdot \hat{t}_u + b$$

## Weighted Random Selection

Let $\Sigma = \sum_{u \in A} S(u)$ be the total score.

Generate random threshold $\theta \sim \text{Uniform}(0, \Sigma)$

Select question $u^*$ where $u^*$ is the first question such that:
$$\sum_{i=1}^{k} S(u_i) \geq \theta$$
where questions are ordered as $u_1, u_2, ..., u_{|A|}$

This implements weighted random selection where questions with higher scores have proportionally higher probability of being selected.
# Data Synchronization Algorithm
As the size and scale of Quizzer grows, so will the amount of data that exists. This algorithm will determine what data is needed by the user's client device and synchronize that data with the central database.
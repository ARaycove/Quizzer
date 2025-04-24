This process will be dedicated to maintaing the list of eligible questions and any complex logic to minimize redundant checks. The question_queue_maintainer process will ultimately rely on this process for a list of eligible questions.

- Initial scan will fetch all user questions
- separate questions with due date longer than 24 hours from due dates shorter than 24 hours
- separate questions within 24 hours or less by inactive and active modules
- any questions determined eligible go immediately in the list
______________________________
- subsequent scans will only be over questions that will become eligible within 24 hours
- The validation function will need to be updated to tell this process that a module has become active.
- If this process get's a signal it will scan the inactive module list for eligibility again

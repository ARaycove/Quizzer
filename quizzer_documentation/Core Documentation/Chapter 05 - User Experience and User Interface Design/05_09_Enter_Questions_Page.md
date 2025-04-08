## Questions Only Entry Page

## Purpose
The Questions Only Entry Page allows contributors to focus solely on generating quality questions from existing source material, supporting the specialization approach for more efficient content creation.
## Interface Elements
- **Source Material Display**: Shows random or selected passages with citations
- **Question Entry Fields**: Multiple text areas for entering different question formulations
- **Question Type Tags**: Options to classify questions (recall, understanding, application, etc.)
- **Media Addition**: Tools to incorporate relevant images or diagrams
- **Difficulty Rating**: Scale to indicate approximate complexity level
- **Submit Button**: Sends questions to the database without answers
- **Skip Button**: Allows moving to another passage if unable to create good questions
## Functionality
When questions are submitted, the system:
1. Records each question in the Question-Answer Pair table with null answer fields
2. Links to the source material via citation
3. Flags these incomplete pairs for answer generation
4. Records the question contributor's ID
5. Makes the questions available in the answer generation task queue

## User Experience Notes
- Remind users that questions should be self-contained without requiring context
- Provide examples of well-constructed questions as reference
- Implement a character count and readability metrics
- Consider gamification elements to encourage quality contributions

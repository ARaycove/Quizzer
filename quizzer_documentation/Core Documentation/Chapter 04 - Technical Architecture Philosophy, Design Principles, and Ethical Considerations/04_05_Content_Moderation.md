# Content Moderation
Content moderation becomes a critical consideration for any educational platform, and Quizzer addresses this through a systematic tagging approach. Rather than imposing blanket restrictions, our philosophy centers on a nuanced understanding of knowledge accessibility and individual readiness.
## Core Philosophy
Quizzer operates on the principle that all knowledge has inherent value within educational contexts. We recognize that content appropriateness is not determined by arbitrary age thresholds but by individual readiness, preferences, and contextual factors. Age-appropriateness is largely a social construct—there is little evidence suggesting that chronological age alone determines when someone becomes ready for specific topics. People don't suddenly mature on their birthdays and become prepared for sensitive materials. Instead, Quizzer implements a system that respects user autonomy while providing robust filtering tools for those who need them. This approach empowers learners and guardians to make informed decisions about content exposure based on their unique circumstances and values.

## Implementation Approach
Content moderation in Quizzer integrates directly with our existing subject and concept classification system:

1. **Classification Method**: Content sensitivity tags will be applied using the same behavioral task methodology detailed in our subject/concept classification system. The process asks: "Does this question-answer pair fall into the following content-moderation category?", a modified approach of that detailed in the [[03_03_breakdown_of_behavioral_tasks#Task_02c Subject and Concept Classification Task| Subject and Concept Classification Task]]
2. **Data Structure**: Classification results will be recorded in a dedicated database table, maintaining our established relational database architecture.
3. **Tagging Process**: Content sensitivity tagging will be implemented as a behavioral task performed by contributors, mirroring our subject/concept classification task structure.
4. **Machine Learning Integration**: A classifier will be trained to detect sensitivity tags alongside subjects and concepts, creating a comprehensive classification system.

## User Controls
The platform will provide transparent content filtering options:
1. **Settings Integration**: Content sensitivity filters will appear under clearly labeled settings, signaling to users that these controls exist for filtering sensitive content.
2. **Pre-emptive Filtering**: Users can express content preferences before being shown any sensitive material.
3. **Tutorial Introduction**: The app's tutorial section will emphasize how to use these content controls effectively.
4. **Parental Controls**: The system will support guardian-managed settings for younger users while maintaining our philosophy that readiness varies individually.

This framework allows for a sophisticated approach to content moderation that respects educational integrity while providing necessary safeguards based on individual needs rather than arbitrary age restrictions. Detailed and hierarchical levels of tagging is the approach in order to ensure that sensitive content does not get shown to user's who either themselves or by their parents deem what content is and isn't appropriate. Hierarchical tagging can include any combination of these tags. We outline the specific tags as follows:
### 1. Violence
- Physical violence (interpersonal conflict, assault)
- Weapons (firearms, knives, improvised, military)
- Blood (minor, significant)
- Gore (explicit visceral content, graphic injuries)
- Death/mortality (natural, accidental, homicide)
- War/armed conflict (historical, contemporary)
- Torture/extreme suffering
- Self-harm
- Animal cruelty/harm
### 2. Medical/Natural Distress Content
- Medical procedures
- Surgical imagery
- Diseases/conditions (visual symptoms)
- Disasters (natural, man-made)
- Accidents (vehicular, industrial)
### 3. Sexual Content
- Sexual education (anatomical, reproductive)
- Sexual health
- Sexual references/innuendo
- Sexual acts (descriptions)
- Nudity (artistic, medical, educational)
- Sexual orientation discussions
- Gender identity discussions
- Reproductive biology
### 4. Social Discourse
- Historical discrimination examples
- Contemporary social justice issues
- Slurs/offensive terminology (in educational context)
- Religious critiques/comparisons
- Cultural practices
- Political ideologies/systems
### 5. Scientific & Historical Controversies
- Evolution/creationism discussions
- Historical revisionism
- Controversial research
- Climate science debates
- Medical/vaccine controversies

# Challenge Mode
Challenge Mode is a simple feature designed to encourage intellectual growth by periodically inviting users to reconsider their content filtering choices. When activated, users will occasionally receive a pop-up suggesting they consider disabling a specific content filter that may be limiting their educational experience. The pop-up clearly explains how removing this particular restriction could broaden their understanding of the world, while emphasizing that the choice remains entirely with the user.

The feature is designed with user autonomy as the priority. Each invitation includes straightforward options: "Review Filter Settings," "Not Now," or "Disable These Suggestions." Users can easily dismiss the notification, adjust their settings, or turn off the feature permanently. For adult users, Challenge Mode is enabled by default as an opt-out feature, while it remains disabled for accounts with parental controls active. This balanced approach respects individual preferences while gently encouraging users to expand beyond potential echo chambers in their educational journey.

This feature is experimental and merely a proposal, if you've read this far please provide some feedback on such a feature.
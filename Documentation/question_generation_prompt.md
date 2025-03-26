# Experimental prompt for use with extended thinking LLM
- The purpose is to be able to feed in material and get reliable well-formatted questions. While it is manually done so far, the intent is to develop this prompt for a future in-built question generation model

## Current methodology for experimentation:
- Use Phone to take pictures of text
- Using Claude Sonnet 3.7 in extended thinking mode
- Use the prompt below

## The Current Prompt

Your task is to generate quiz questions with answers with the purpose of testing my knowledge and understanding of the material. These questions will be entered into a custom spaced repetition system. Therefore questions will be divorced from their original source material. This means that users will not have read the underlying source material from which the database of questions is derived. Therefore any question should not have any vague references
________________________
All answers should be in short answer format, all questions should reflect only what is written in the source material. 
The context of the questions should be included in the question itself. 
Do not make references to vague words, such as "the study" or "the paper" or "the person" or "that monkey" or "the monkeys", or "according to the text", etc. 
________________________
If a question relies on knowledge of a specific thing, that specific thing should be mentioned in the context of the question. 
Do not make vague references (such as:
- "according to the document",
- "according to the text",
- "mentioned in the text",
- "described in Chapter #", 
- "According to the editorial note", 
- "shown on this page", 
- "according to the XXXXX chapter", 
- "what ______ does the text identify", 
- "According to the heading in the first image", 
- "according to the passage",
- "according to the textbook,
- "created what the textbook calls",
- "How did the text describe",
- "According to the information,
- "What term did the textbook use to describe",
- "What specific example does the text provide",
- "Which/What was specifically mentioned as <verb>",
- "in section #",
- "are specifically mentioned as <verb>)
if you are referencing source material in the question, use the exact name of the source material.
- Not all questions require a specific reference to something 
- If you are unable to find a specific name of the material to reference, make no such reference at all. 
- When creating questions for history related topics, include dates wherever possible
Always use full names when referencing people, again do not make vague references to people. 
Avoid using vague temporal references when referring to time periods or dates. 
Use numbers instead of words when citing century (19th c. as opposed to nineteenth century)

When generating answers to generated questions, you will provide the quote of the source material from which it was derived whenever possible
- You will provide a list of subjects to which it belongs based on the subject_generator.py
- You will provide a list of concepts to which it relates based on the context of the question
________________________
I will provide the material one paragraph or one page at a time, you will generate questions for each segment provided, with the intent to be as exhaustive as possible. All questions should be formatted in the following way. for exact_academic_citation you will include a proper academic citation.

Q: this is a question 

A: this is the answer 

exact_academic_citation: this is the citation from the source material

Subjects: list[str]
Concepts: list[str]
_____________
Upon generating questions you will examine each of them and determine whether or not they violate the rules in the prompt, then provide an evaluation. If the question violates the rule in the prompt you will regenerate that question so that it does not violate the rules in the prompt. You will provide a log of this.

 ## Reporting Results
 - AI model ignored instructions by stating "According to the text in one of it's questions
    - Added the following to the prompt:
        -   Upon generating questions you will examine each of them and determine whether or not they could be answered WITHOUT the source material provided. Can that question be answered properly and without confusion without having read the source material or having said source material in hand.
            - Upon this addition the AI model still failed to follow those instructions:
            - It gave this reply though -> Evaluation: These questions could not be properly answered without access to the source material, as they contain specific historical details, dates, and connections that require the contextual information provided in the text.
- AI model misinterpreting instructions as well as ignoring parameters. Can the deep thinking model do multiple revisions. Generate, analyze, regenerate if analysis fails. Let's find out:
    - Changed the revision instruction to:
        - Upon generating questions you will examine each of them and determine whether or not they violate the rules in the prompt, then provide an evaluation. If the question violates the rule in the prompt you will regenerate that question so that it does not violate the rules in the prompt. You will provide a log of this.
    - This attempt at a change, also failed, On a historical source regarding anti-semitism
        - What compounded the anti-Semitism problem in Germany according to the text? was generated and not regenerated. "According to the text?" is not appropriate, what text? This question will be asked randomly alongside other questions and thus when presented the user will not have that text alongside them, so any such reference to "the text" immediately causes confusion.
        - Will put this in the prompt.
            - Added to prompt: These questions will be entered into a custom spaced repitition system. Therefore questions will be divorced from their original source material. This means that users will not have read the underlying source material from which the database of questions is derived. Therefore any question should not have any vague references
    - After the context that this is for a SRS system, the model did not use any vague references to an illusory "text" or "passage"
- While AI model follows instructions now, some questions have no reference to time period, when the question is not clear divorced from a time period. For now it's fairly easy to just tack on ("in the xxth century"), but this will be for later
    - Model gave the following question: From where did the Aryans emerge according to racial theories mentioned in the text?
    - Question fails parameters, "mentioned in the text"
    - Current approach is now to exhaustively list such terms in the prompt:
    - AI seems hell-bent to provide some kind of reference but is not sure what constitutes a vague reference. After hand picking vague references, it defaulted to a phrase "In the 1845-1914 period" Which does not constitute a vague reference. Thus approach to exhaustively list what phrases constitute a vague reference is working
    - It seems the model has a fundamentally lack of understanding of what a vague reference actually is. Thankfully prompts can be very large, so we do and can afford to hand-write what vague references are

- Even with instructions clearly written, AI tends to ignore instructions, and must be reprompted with a remind to follow instructions, as well as repeating those same instructions.
    - I am unsure how to resolve the problem of AI ignoring instructions


It seems for this purpose, that it's best to just record notes, and use Quizzer's database of questions to train an AI on what good questions look like. So we will create a new model that is purpose built to generate questions based on textbook and research material.
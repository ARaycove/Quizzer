# Task_01: Source Material generation and classification
This grouping of behavioral tasks centers on the systematic extraction and processing of academic content into discrete "passages"—defined as self-contained textual units that maintain coherent meaning when isolated from their original context. While these passages may encompass various scopes ranging from individual paragraphs to entire chapters, the guiding principle is maximal granularity to facilitate precise learning unit construction.

The methodological approach maintains granularity as its core design principle, breaking down the content processing workflow into discrete operations performed by different participants. This design creates natural quality control checkpoints while minimizing cognitive load per participant. In this distributed workflow, one participant extracts passages from source texts, another identifies key terminological elements within those passages, and a third validates the source material's academic integrity. This separation of concerns ensures both procedural integrity and data quality while maximizing the potential for parallel processing across the participant network.
## Task_01a: Extract passages from Source Material
This task requires participants to analyze academic source materials and extract meaningful passages while recording their corresponding citations accurately. Source materials are restricted to academically rigorous content including peer-reviewed journal articles, university textbooks, doctoral dissertations, and other scholarly works commonly found in academic libraries. This constraint ensures Quizzer functions as a validated memory retention platform for factual knowledge typically acquired in accredited educational institutions.
### Procedural Guidelines
Participants should follow specific extraction guidelines to maintain content integrity. The optimal extraction points are natural section boundaries demarcated by headers, subheaders, or chapter divisions. Each chapter typically contains multiple potential passages that can stand alone while preserving semantic coherence. For works with less obvious structure, participants should identify conceptually complete units that maintain meaning when separated from surrounding text.

For content extraction, participants should digitally capture text through direct copying from electronic sources whenever possible to prevent transcription errors. For physical sources, participants may type content manually or use scanning technology, provided in the UI. All associated visual elements directly referenced in the passage should be included in the appropriate database field.

 %% Insert an example of a properly extracted passage with citation %% 
 %% Min-Max length guidelines on passages? %%
 %% Guidelines on if work cites other works %%

All citations will follow the BibTeX format as the platform standard. Different entry types (book, article, thesis, etc.) will use appropriate BibTeX fields while maintaining consistent formatting for database integration. In the task entry field, the parameters for the citation will be provided in discrete UI elements to ensure that the format is recorded properly. Each field will replicate as a field in the relational database structure. The data entry type will be a discrete set of 14 types (article, book, booklet, conference, inbook, incollection, inproceedings, manual, masterthesis, misc, phdthesis, proceedings, techreport, unpublished). There are standard fields for BibTex format, which are listed as follows: address, annote, author, booktitle, chapter, edition, editor, howpublished, institution, journal, month, note, number, organization, pages, publisher, school, series, title, type, volume, year, doi, issn, isbn, url.

Specific details of what these fields mean will be included in the UI of the task as tooltips.

See the following URL for more specific details on BibText: https://www.bibtex.com/g/bibtex-format/.
### Example Implementation

### Technical Implementation
This implementation stores content in a structured database with separate fields for textual content ("src_text"), images ("src_image"), audio ("src_audio"), and video ("src_video"), alongside the complete citation information. This structured approach to content acquisition creates the foundational knowledge repository that enables Quizzer's question generation processes while maintaining proper academic attribution and content integrity. 
## Task_01b: Key Term identification Task:
This task builds upon completed source material extraction (Task_01a) and focuses on identifying the significant terminology within each academic passage. Participants systematically extract key terms that represent core concepts, entities, and specialized vocabulary contained in the passage. This process creates a semantic framework that enables later classification, question generation, and relationship mapping across the knowledge base.
### Procedural Guidelines
- Participants will be presented with a previously extracted passage without seeing its citation information to prevent bias.
- Participants should read the entire passage carefully, identifying terms in the following categories:
    - **Technical concepts**: Specialized terminology specific to the academic field
    - **Named entities**: People, organizations, places, events, or other proper nouns
    - **Processes**: Named methodologies, systems, or procedures
    - **Theoretical constructs**: Models, frameworks, or paradigms
    - **Quantitative metrics**: Specific measurements, scales, or indicators
- Terms should be recorded as they appear in the text, maintaining original capitalization. However for core concepts, some interpretation may be required
- Multi-word phrases should be preserved when they represent a single concept (e.g., "educational data mining" rather than separate entries for "educational," "data," and "mining").
- Common words should only be included if they have specialized meaning within the context of the passage.
- Terms that appear multiple times within a single passage should only be recorded once

### Example Implementation
**Sample Passage:**
Educational data mining employs statistical, machine-learning, and data-mining algorithms over educational data. The Ebbinghaus forgetting curve, first documented in 1885, demonstrates how information is lost over time when there is no attempt to retain it. Modern implementations like the Leitner system leverage this understanding to create effective spaced repetition schedules. Researchers such as Murre and Dros confirmed the validity of Ebbinghaus's work in their 2015 replication study.

**Expected Output** (Not exhaustive)
"educational data mining", "statistical algorithms", "machine-learning algorithms", "data-mining algorithms", "Ebbinghaus", "Ebbinghaus forgetting curve", "Leitner", "Murre", "Dros", "spaced repetition", "Leitner system"

### Technical Implementation
The identified key terms from each passage will be transformed into a structured database representation. Rather than storing the raw list of terms, each unique key term across the platform is one-hot encoded into the database table for this task. For each record, these fields contain binary values (0 or 1) indicating whether that specific term appears in the associated passage.

The result of this task is a standardized set of terms that, when processed, create a semantic fingerprint of each passage through binary indicators. This approach enables efficient semantic searching, concept mapping, and relationship identification across the knowledge base.

## Task_01c: Review Records of Entry:
%% Introductory, descirbe the overall task and purpose %%
When a record is made the person submitting that information will have their id recorded, this is to track who has done what. This serves to help oust malicious actors, and gives us the ability to ensure that those reviewing a record for accuracy is not the same one that submitted the record.

The goal of this task is to read the source material entered and check it against it's citation. Ensure the source material is from the entered citation, if this fails the record should either be corrected or deleted. The reviewer should also ensure the citation provided is correct and of correct format.
 %% We haven't detailed the role of the reviewer in this task %% 
 
 %% Specific guidelines and implementation %%
%% Review citations are accurate %%
%% Review Key Terms derived %%
%% If review process fails, flag for removal otherwise flag as correct.  %%
%% Expected Results %%
If flagged for removal both the removal_flag becomes true and the has_been_reviewed field becomes True, otherwise only the has_been reviewed field is marked True

Data Structures are mentioned in Chapter 8:
[[08_06_Citation_and_Source_Material_Table]]
[[08_07_Source_Material_Key_Term_Table]]

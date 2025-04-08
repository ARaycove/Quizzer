# Source Material Entry Page

## Purpose

The Source Material Entry Page allows users to extract academic passages from source materials with proper citations, creating the foundation of verified educational content that powers Quizzer's question generation processes.

## Interface Elements

- **Source Material Text Area**: A large text editor for entering academic passages
- **Citation Fields**: Structured input fields for BibTeX citation components:
    - Entry Type dropdown (article, book, thesis, etc.)
    - Author field
    - Title field
    - Publication details (journal, publisher, year, etc.)
    - DOI/URL field
- **Media Upload**: Options to attach images, audio, or video referenced in the passage
- **Preview Panel**: Shows formatted citation and content preview
- **Key Term Suggestion**: AI-assisted identification of key terms in the entered passage
- **Submit Button**: Sends the entry to the database
- **Review Toggle**: Option for contributors to review others' submissions
## Functionality

When a user submits content, the system:
1. Stores the passage with citation in the Source_Material table
2. Records the submitter's ID
3. Flags the content for review
4. Identifies potential key terms for later verification
5. Makes the content available for question generation

## User Experience Notes
- For desktop environments, provide full-featured editing capabilities
- For mobile, simplify the interface but maintain core functionality
- Include tooltips explaining BibTeX fields and proper citation formatting
- Display a progress indicator showing where this task fits in the content development pipeline
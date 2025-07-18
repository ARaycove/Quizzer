This document outlines a comprehensive and trimmed list of fields for a SQL citation table, specifically designed for SQLite. It details the structure, data types, and primary key definition, along with conditional requirements for data insertion based on the citation type.
Core Identification Fields

These fields are essential for uniquely identifying and categorizing each citation entry.

    title (TEXT NOT NULL): The main title of the work being cited (e.g., book title, article title, webpage title).

    subtitle (TEXT): Any subtitle associated with the main title.

    citation_type (TEXT NOT NULL): Specifies the general type of source (e.g., 'Book', 'Journal Article', 'Website', 'Conference Paper', 'Thesis', 'Report', 'Patent', 'Legislation', 'Artwork', 'Interview', 'Podcast', 'Video', 'Software', 'Standard'). This can be used for conditional logic in citation generation.

Primary Key: The primary key for this table will be a composite key consisting of title, subtitle, publisher, and publication_date.
Author/Creator Fields

These fields capture information about the individuals or entities responsible for the work.

    author_first_name (TEXT NOT NULL): First name of the primary author.

    author_middle_initial (TEXT): Middle initial(s) of the primary author.

    author_last_name (TEXT NOT NULL): Last name of the primary author.

    author_suffix (TEXT): Suffix for the primary author (e.g., 'Jr.', 'Sr.', 'III').

    corporate_author (TEXT): Name of the corporate or organizational author, if applicable.

    additional_authors (TEXT): A field to store multiple authors, typically as a delimited string (e.g., comma-separated names) or a simple text blob. You'll need to parse this manually in your application.

Publication Details Fields

These fields provide information about where and when the work was published or released.

    publication_date (TEXT NOT NULL): The full date of publication, stored as a string (e.g., 'YYYY-MM-DD').

    publisher (TEXT NOT NULL): The name of the publisher.

    publisher_location (TEXT): The city and state/country of the publisher.

    edition (TEXT): The edition of the work (e.g., '2nd ed.', 'Revised Edition').

    volume (TEXT): Volume number (for journals, multi-volume books).

    issue (TEXT): Issue number (for journals).

    series_title (TEXT): The title of the series the work belongs to.

    series_number (TEXT): The number within the series.

    pages (TEXT): Specific page numbers cited (e.g., 'pp. 45-52') or total pages for a book.

    chapter_title (TEXT): The title of a specific chapter or section within a larger work.

    chapter_number (TEXT): The number of the chapter.

Digital & Access Fields

Crucial for online sources and ensuring retrievability.

    url (TEXT): The direct URL to the online material.

    doi (TEXT): Digital Object Identifier.

Specific Source Type Fields

These fields are tailored for particular types of sources.

For Journal Articles:

    journal_title (TEXT): The full title of the journal.

    journal_abbreviation (TEXT): Common abbreviation for the journal title.

For Conference Papers:

    conference_name (TEXT): Name of the conference.

    conference_location (TEXT): Location where the conference was held.

    conference_date (TEXT): Date(s) of the conference, stored as a string.

For Theses/Dissertations:

    degree_type (TEXT): Type of degree (e.g., 'Ph.D. dissertation', 'Master's thesis').

    university (TEXT): The university where the thesis was submitted.

For Reports:

    report_number (TEXT): The report number or identification.

    institution (TEXT): The institution or organization that issued the report.

For Patents:

    patent_number (TEXT): The patent number.

    patent_office (TEXT): The patent office that issued it (e.g., 'U.S. Patent and Trademark Office').

For Legislation/Legal Documents:

    legal_citation (TEXT): The specific legal citation format (e.g., '42 U.S.C. § 1983').

    court (TEXT): The court involved.

    case_name (TEXT): The name of the case.

Descriptive & Annotative Fields

These fields provide additional context and utility.

    abstract (TEXT): A brief summary of the work.

    notes (TEXT): Any personal notes or annotations about the citation.

    full_document (TEXT NOT NULL): The full content of the document, stored in Markdown format.

    media (TEXT): A JSON string list of file names for media (images, audio, video, etc.) referenced within the document (e.g., ["image1.png", "audio.mp3", "video.mp4"]).

Additional Details: Conditional NOT NULL Fields for Data Insertion

While SQLite's schema allows many fields to be nullable, the practical requirements for generating complete and accurate citations mean that certain fields become conditionally mandatory based on the citation_type. Your application's insert functionality should enforce these as NOT NULL at the time of data entry for specific citation types.

Below is a breakdown of fields that should be considered mandatory (i.e., NOT NULL) during insertion, depending on the citation_type:

    For all citation_types (universal requirements):

        title

        citation_type

        publication_date

        publisher

        author_first_name

        author_last_name

        full_document

    If citation_type is 'Book':

        chapter_title

        chapter_number

        pages

        publisher_location (highly recommended for complete citations)

    If citation_type is 'Journal Article':

        journal_title

        volume

        issue

        pages

    If citation_type is 'Website':

        url

    If citation_type is 'Conference Paper':

        conference_name

        conference_location

        conference_date

    If citation_type is 'Thesis' or 'Dissertation':

        degree_type

        university

    If citation_type is 'Report':

        institution (the organization that issued the report)

    If citation_type is 'Patent':

        patent_number

        patent_office

    If citation_type is 'Legislation':

        legal_citation

    If citation_type is 'Legal Document':

        At least one of: legal_citation, OR both case_name and court

    If citation_type is 'Artwork':

        publisher_location

        media

    If citation_type is 'Interview':

        publisher_location

This conditional enforcement at the application layer will ensure that all necessary information is present for accurate citation generation, even for fields that are not strictly NOT NULL in the SQLite table definition.
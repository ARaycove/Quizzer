import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/00_database_manager/database_monitor.dart';

// Table name and field constants
const String citationTableName = 'citations';

// Core Identification Fields
const String titleField = 'title';
const String subtitleField = 'subtitle';
const String citationTypeField = 'citation_type';

// Author/Creator Fields
const String authorFirstNameField = 'author_first_name';
const String authorMiddleInitialField = 'author_middle_initial';
const String authorLastNameField = 'author_last_name';
const String authorSuffixField = 'author_suffix';
const String corporateAuthorField = 'corporate_author';
const String additionalAuthorsField = 'additional_authors';

// Publication Details Fields
const String publicationDateField = 'publication_date';
const String publisherField = 'publisher';
const String publisherLocationField = 'publisher_location';
const String editionField = 'edition';
const String volumeField = 'volume';
const String issueField = 'issue';
const String seriesTitleField = 'series_title';
const String seriesNumberField = 'series_number';
const String pagesField = 'pages';
const String chapterTitleField = 'chapter_title';
const String chapterNumberField = 'chapter_number';

// Digital & Access Fields
const String urlField = 'url';
const String doiField = 'doi';

// Specific Source Type Fields - Journal Articles
const String journalTitleField = 'journal_title';
const String journalAbbreviationField = 'journal_abbreviation';

// Specific Source Type Fields - Conference Papers
const String conferenceNameField = 'conference_name';
const String conferenceLocationField = 'conference_location';
const String conferenceDateField = 'conference_date';

// Specific Source Type Fields - Theses/Dissertations
const String degreeTypeField = 'degree_type';
const String universityField = 'university';

// Specific Source Type Fields - Reports
const String reportNumberField = 'report_number';
const String institutionField = 'institution';

// Specific Source Type Fields - Patents
const String patentNumberField = 'patent_number';
const String patentOfficeField = 'patent_office';

// Specific Source Type Fields - Legislation/Legal Documents
const String legalCitationField = 'legal_citation';
const String courtField = 'court';
const String caseNameField = 'case_name';

// Descriptive & Annotative Fields
const String abstractField = 'abstract';
const String notesField = 'notes';
const String fullDocumentField = 'full_document';
const String mediaField = 'media';

// Create table SQL with composite primary key
const String createCitationTableSQL = '''
  CREATE TABLE IF NOT EXISTS $citationTableName (
    $titleField TEXT NOT NULL,
    $subtitleField TEXT,
    $citationTypeField TEXT NOT NULL,
    $authorFirstNameField TEXT NOT NULL,
    $authorMiddleInitialField TEXT,
    $authorLastNameField TEXT NOT NULL,
    $authorSuffixField TEXT,
    $corporateAuthorField TEXT,
    $additionalAuthorsField TEXT,
    $publicationDateField TEXT NOT NULL,
    $publisherField TEXT NOT NULL,
    $publisherLocationField TEXT,
    $editionField TEXT,
    $volumeField TEXT,
    $issueField TEXT,
    $seriesTitleField TEXT,
    $seriesNumberField TEXT,
    $pagesField TEXT,
    $chapterTitleField TEXT,
    $chapterNumberField TEXT,
    $urlField TEXT,
    $doiField TEXT,
    $journalTitleField TEXT,
    $journalAbbreviationField TEXT,
    $conferenceNameField TEXT,
    $conferenceLocationField TEXT,
    $conferenceDateField TEXT,
    $degreeTypeField TEXT,
    $universityField TEXT,
    $reportNumberField TEXT,
    $institutionField TEXT,
    $patentNumberField TEXT,
    $patentOfficeField TEXT,
    $legalCitationField TEXT,
    $courtField TEXT,
    $caseNameField TEXT,
    $abstractField TEXT,
    $notesField TEXT,
    $fullDocumentField TEXT NOT NULL,
    $mediaField TEXT,
    has_been_synced INTEGER DEFAULT 0,
    edits_are_synced INTEGER DEFAULT 0,
    last_modified_timestamp TEXT,
    PRIMARY KEY ($titleField, $subtitleField, $publisherField, $publicationDateField)
  )
''';

// Verify table exists and create if needed
Future<void> verifyCitationTable(dynamic db) async {
  QuizzerLogger.logMessage('Verifying citations table existence');
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='$citationTableName'"
  );
  
  if (tables.isEmpty) {
    QuizzerLogger.logMessage('Citations table does not exist, creating it');
    await db.execute(createCitationTableSQL);
    QuizzerLogger.logSuccess('Citations table created successfully');
  } else {
    QuizzerLogger.logMessage('Citations table exists');
  }
}

// Insert a new citation
Future<void> insertCitation({
  required String title,
  String? subtitle,
  required String citationType,
  required String authorFirstName,
  String? authorMiddleInitial,
  required String authorLastName,
  String? authorSuffix,
  String? corporateAuthor,
  String? additionalAuthors,
  required String publicationDate,
  required String publisher,
  String? publisherLocation,
  String? edition,
  String? volume,
  String? issue,
  String? seriesTitle,
  String? seriesNumber,
  String? pages,
  String? chapterTitle,
  String? chapterNumber,
  String? url,
  String? doi,
  String? journalTitle,
  String? journalAbbreviation,
  String? conferenceName,
  String? conferenceLocation,
  String? conferenceDate,
  String? degreeType,
  String? university,
  String? reportNumber,
  String? institution,
  String? patentNumber,
  String? patentOffice,
  String? legalCitation,
  String? court,
  String? caseName,
  String? abstract,
  String? notes,
  required String fullDocument,
  List<String>? media,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Inserting new citation: $title');
    await verifyCitationTable(db);
    
    // Prepare the raw data map
    final Map<String, dynamic> data = {
      titleField: title,
      subtitleField: subtitle,
      citationTypeField: citationType,
      authorFirstNameField: authorFirstName,
      authorMiddleInitialField: authorMiddleInitial,
      authorLastNameField: authorLastName,
      authorSuffixField: authorSuffix,
      corporateAuthorField: corporateAuthor,
      additionalAuthorsField: additionalAuthors,
      publicationDateField: publicationDate,
      publisherField: publisher,
      publisherLocationField: publisherLocation,
      editionField: edition,
      volumeField: volume,
      issueField: issue,
      seriesTitleField: seriesTitle,
      seriesNumberField: seriesNumber,
      pagesField: pages,
      chapterTitleField: chapterTitle,
      chapterNumberField: chapterNumber,
      urlField: url,
      doiField: doi,
      journalTitleField: journalTitle,
      journalAbbreviationField: journalAbbreviation,
      conferenceNameField: conferenceName,
      conferenceLocationField: conferenceLocation,
      conferenceDateField: conferenceDate,
      degreeTypeField: degreeType,
      universityField: university,
      reportNumberField: reportNumber,
      institutionField: institution,
      patentNumberField: patentNumber,
      patentOfficeField: patentOffice,
      legalCitationField: legalCitation,
      courtField: court,
      caseNameField: caseName,
      abstractField: abstract,
      notesField: notes,
      fullDocumentField: fullDocument,
      mediaField: media,
      'has_been_synced': 0,
      'edits_are_synced': 0,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String()
    };

    // Validate the citation data before insertion
    if (!validateCitationData(data)) {
      throw Exception('Citation validation failed. Check logs for specific validation errors.');
    }

    // Use the universal insert helper with ConflictAlgorithm.replace
    final int result = await insertRawData(
      citationTableName,
      data,
      db,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    if (result > 0) {
      QuizzerLogger.logSuccess('Citation $title inserted/replaced successfully');
    } else {
      QuizzerLogger.logWarning('Insert/replace operation for citation $title returned $result.');
    }
  } catch (e) {
    QuizzerLogger.logError('Error inserting citation - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Update a citation
Future<void> updateCitation({
  required String title,
  required String subtitle,
  required String publisher,
  required String publicationDate,
  String? newTitle,
  String? newSubtitle,
  String? citationType,
  String? authorFirstName,
  String? authorMiddleInitial,
  String? authorLastName,
  String? authorSuffix,
  String? corporateAuthor,
  String? additionalAuthors,
  String? newPublicationDate,
  String? newPublisher,
  String? publisherLocation,
  String? edition,
  String? volume,
  String? issue,
  String? seriesTitle,
  String? seriesNumber,
  String? pages,
  String? chapterTitle,
  String? chapterNumber,
  String? url,
  String? doi,
  String? journalTitle,
  String? journalAbbreviation,
  String? conferenceName,
  String? conferenceLocation,
  String? conferenceDate,
  String? degreeType,
  String? university,
  String? reportNumber,
  String? institution,
  String? patentNumber,
  String? patentOffice,
  String? legalCitation,
  String? court,
  String? caseName,
  String? abstract,
  String? notes,
  String? fullDocument,
  List<String>? media,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Updating citation: $title');
    await verifyCitationTable(db);
    final updates = <String, dynamic>{};
    
    // Handle primary key changes if provided
    if (newTitle != null && newTitle != title) {
      updates[titleField] = newTitle;
      updates['edits_are_synced'] = 0;
      QuizzerLogger.logMessage('Title will be changed from "$title" to "$newTitle"');
    }
    if (newSubtitle != null && newSubtitle != subtitle) {
      updates[subtitleField] = newSubtitle;
      updates['edits_are_synced'] = 0;
    }
    if (newPublisher != null && newPublisher != publisher) {
      updates[publisherField] = newPublisher;
      updates['edits_are_synced'] = 0;
    }
    if (newPublicationDate != null && newPublicationDate != publicationDate) {
      updates[publicationDateField] = newPublicationDate;
      updates['edits_are_synced'] = 0;
    }
    
    // Handle other field updates
    if (citationType != null) {
      updates[citationTypeField] = citationType;
      updates['edits_are_synced'] = 0;
    }
    if (authorFirstName != null) {
      updates[authorFirstNameField] = authorFirstName;
      updates['edits_are_synced'] = 0;
    }
    if (authorMiddleInitial != null) {
      updates[authorMiddleInitialField] = authorMiddleInitial;
      updates['edits_are_synced'] = 0;
    }
    if (authorLastName != null) {
      updates[authorLastNameField] = authorLastName;
      updates['edits_are_synced'] = 0;
    }
    if (authorSuffix != null) {
      updates[authorSuffixField] = authorSuffix;
      updates['edits_are_synced'] = 0;
    }
    if (corporateAuthor != null) {
      updates[corporateAuthorField] = corporateAuthor;
      updates['edits_are_synced'] = 0;
    }
    if (additionalAuthors != null) {
      updates[additionalAuthorsField] = additionalAuthors;
      updates['edits_are_synced'] = 0;
    }
    if (publisherLocation != null) {
      updates[publisherLocationField] = publisherLocation;
      updates['edits_are_synced'] = 0;
    }
    if (edition != null) {
      updates[editionField] = edition;
      updates['edits_are_synced'] = 0;
    }
    if (volume != null) {
      updates[volumeField] = volume;
      updates['edits_are_synced'] = 0;
    }
    if (issue != null) {
      updates[issueField] = issue;
      updates['edits_are_synced'] = 0;
    }
    if (seriesTitle != null) {
      updates[seriesTitleField] = seriesTitle;
      updates['edits_are_synced'] = 0;
    }
    if (seriesNumber != null) {
      updates[seriesNumberField] = seriesNumber;
      updates['edits_are_synced'] = 0;
    }
    if (pages != null) {
      updates[pagesField] = pages;
      updates['edits_are_synced'] = 0;
    }
    if (chapterTitle != null) {
      updates[chapterTitleField] = chapterTitle;
      updates['edits_are_synced'] = 0;
    }
    if (chapterNumber != null) {
      updates[chapterNumberField] = chapterNumber;
      updates['edits_are_synced'] = 0;
    }
    if (url != null) {
      updates[urlField] = url;
      updates['edits_are_synced'] = 0;
    }
    if (doi != null) {
      updates[doiField] = doi;
      updates['edits_are_synced'] = 0;
    }
    if (journalTitle != null) {
      updates[journalTitleField] = journalTitle;
      updates['edits_are_synced'] = 0;
    }
    if (journalAbbreviation != null) {
      updates[journalAbbreviationField] = journalAbbreviation;
      updates['edits_are_synced'] = 0;
    }
    if (conferenceName != null) {
      updates[conferenceNameField] = conferenceName;
      updates['edits_are_synced'] = 0;
    }
    if (conferenceLocation != null) {
      updates[conferenceLocationField] = conferenceLocation;
      updates['edits_are_synced'] = 0;
    }
    if (conferenceDate != null) {
      updates[conferenceDateField] = conferenceDate;
      updates['edits_are_synced'] = 0;
    }
    if (degreeType != null) {
      updates[degreeTypeField] = degreeType;
      updates['edits_are_synced'] = 0;
    }
    if (university != null) {
      updates[universityField] = university;
      updates['edits_are_synced'] = 0;
    }
    if (reportNumber != null) {
      updates[reportNumberField] = reportNumber;
      updates['edits_are_synced'] = 0;
    }
    if (institution != null) {
      updates[institutionField] = institution;
      updates['edits_are_synced'] = 0;
    }
    if (patentNumber != null) {
      updates[patentNumberField] = patentNumber;
      updates['edits_are_synced'] = 0;
    }
    if (patentOffice != null) {
      updates[patentOfficeField] = patentOffice;
      updates['edits_are_synced'] = 0;
    }
    if (legalCitation != null) {
      updates[legalCitationField] = legalCitation;
      updates['edits_are_synced'] = 0;
    }
    if (court != null) {
      updates[courtField] = court;
      updates['edits_are_synced'] = 0;
    }
    if (caseName != null) {
      updates[caseNameField] = caseName;
      updates['edits_are_synced'] = 0;
    }
    if (abstract != null) {
      updates[abstractField] = abstract;
      updates['edits_are_synced'] = 0;
    }
    if (notes != null) {
      updates[notesField] = notes;
      updates['edits_are_synced'] = 0;
    }
    if (fullDocument != null) {
      updates[fullDocumentField] = fullDocument;
      updates['edits_are_synced'] = 0;
    }
    if (media != null) {
      updates[mediaField] = media;
      updates['edits_are_synced'] = 0;
    }
    
    // Add fields that are always updated
    updates['last_modified_timestamp'] = DateTime.now().toUtc().toIso8601String();

    // Create a complete data map for validation (combining existing data with updates)
    final Map<String, dynamic> validationData = {
      titleField: newTitle ?? title,
      subtitleField: newSubtitle ?? subtitle,
      citationTypeField: citationType ?? (await getCitation(title: title, subtitle: subtitle, publisher: publisher, publicationDate: publicationDate))?[citationTypeField],
      authorFirstNameField: authorFirstName ?? (await getCitation(title: title, subtitle: subtitle, publisher: publisher, publicationDate: publicationDate))?[authorFirstNameField],
      authorLastNameField: authorLastName ?? (await getCitation(title: title, subtitle: subtitle, publisher: publisher, publicationDate: publicationDate))?[authorLastNameField],
      publicationDateField: newPublicationDate ?? publicationDate,
      publisherField: newPublisher ?? publisher,
      fullDocumentField: fullDocument ?? (await getCitation(title: title, subtitle: subtitle, publisher: publisher, publicationDate: publicationDate))?[fullDocumentField],
    };

    // Validate the updated citation data
    if (!validateCitationData(validationData)) {
      throw Exception('Citation validation failed for update. Check logs for specific validation errors.');
    }

    // Use the universal update helper
    final int result = await updateRawData(
      citationTableName,
      updates,
      '$titleField = ? AND $subtitleField = ? AND $publisherField = ? AND $publicationDateField = ?',
      [title, subtitle, publisher, publicationDate],
      db,
    );
    
    if (result > 0) {
      QuizzerLogger.logSuccess('Citation $title updated successfully ($result row affected).');
    } else {
      QuizzerLogger.logWarning('Update operation for citation $title affected 0 rows. Citation might not exist or data was unchanged.');
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating citation - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Get a citation by primary key
Future<Map<String, dynamic>?> getCitation({
  required String title,
  required String subtitle,
  required String publisher,
  required String publicationDate,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching citation: $title');
    await verifyCitationTable(db);
    
    // Use the universal query helper
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      citationTableName,
      db,
      where: '$titleField = ? AND $subtitleField = ? AND $publisherField = ? AND $publicationDateField = ?',
      whereArgs: [title, subtitle, publisher, publicationDate],
      limit: 2, // Limit to 2 to detect if PK constraint is violated
    );

    if (results.isEmpty) {
      QuizzerLogger.logMessage('Citation $title not found');
      return null;
    } else if (results.length > 1) {
      QuizzerLogger.logError('Found multiple citations with the same primary key: $title. PK constraint violation?');
      throw StateError('Found multiple citations with the same primary key: $title');
    }

    // Get the single, already decoded map
    final decodedCitation = results.first;
    
    QuizzerLogger.logValue('Retrieved and processed citation: $title');
    return decodedCitation;
  } catch (e) {
    QuizzerLogger.logError('Error getting citation - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Get all citations
Future<List<Map<String, dynamic>>> getAllCitations() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching all citations');
    await verifyCitationTable(db);
    
    // Use the universal query helper
    final List<Map<String, dynamic>> decodedCitations = await queryAndDecodeDatabase(
      citationTableName,
      db,
      // No WHERE clause needed to get all
    );

    QuizzerLogger.logValue('Retrieved ${decodedCitations.length} citations');
    return decodedCitations;
  } catch (e) {
    QuizzerLogger.logError('Error getting all citations - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Get unsynced citations
Future<List<Map<String, dynamic>>> getUnsyncedCitations() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching unsynced citations');
    await verifyCitationTable(db);
    
    // Use the universal query helper to get citations that need syncing
    final List<Map<String, dynamic>> unsyncedCitations = await queryAndDecodeDatabase(
      citationTableName,
      db,
      where: 'edits_are_synced = ?',
      whereArgs: [0],
    );

    QuizzerLogger.logValue('Found ${unsyncedCitations.length} unsynced citations');
    return unsyncedCitations;
  } catch (e) {
    QuizzerLogger.logError('Error getting unsynced citations - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Update citation sync flags
Future<void> updateCitationSyncFlags({
  required String title,
  required String subtitle,
  required String publisher,
  required String publicationDate,
  required bool hasBeenSynced,
  required bool editsAreSynced,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Updating sync flags for citation: $title');
    await verifyCitationTable(db);
    
    final updates = {
      'has_been_synced': hasBeenSynced ? 1 : 0,
      'edits_are_synced': editsAreSynced ? 1 : 0,
    };

    final int result = await updateRawData(
      citationTableName,
      updates,
      '$titleField = ? AND $subtitleField = ? AND $publisherField = ? AND $publicationDateField = ?',
      [title, subtitle, publisher, publicationDate],
      db,
    );
    
    if (result > 0) {
      QuizzerLogger.logSuccess('Sync flags updated for citation $title');
    } else {
      QuizzerLogger.logWarning('No rows affected when updating sync flags for citation $title');
    }
  } catch (e) {
    QuizzerLogger.logError('Error updating citation sync flags - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Upserts a citation from inbound sync and sets sync flags to 1.
/// This function is specifically for handling inbound sync operations.
Future<void> upsertCitationFromInboundSync({
  required String title,
  String? subtitle,
  required String citationType,
  required String authorFirstName,
  String? authorMiddleInitial,
  required String authorLastName,
  String? authorSuffix,
  String? corporateAuthor,
  String? additionalAuthors,
  required String publicationDate,
  required String publisher,
  String? publisherLocation,
  String? edition,
  String? volume,
  String? issue,
  String? seriesTitle,
  String? seriesNumber,
  String? pages,
  String? chapterTitle,
  String? chapterNumber,
  String? url,
  String? doi,
  String? journalTitle,
  String? journalAbbreviation,
  String? conferenceName,
  String? conferenceLocation,
  String? conferenceDate,
  String? degreeType,
  String? university,
  String? reportNumber,
  String? institution,
  String? patentNumber,
  String? patentOffice,
  String? legalCitation,
  String? court,
  String? caseName,
  String? abstract,
  String? notes,
  required String fullDocument,
  List<String>? media,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Upserting citation $title from inbound sync...');

    await verifyCitationTable(db);

    // Prepare the data map with all fields
    final Map<String, dynamic> data = {
      titleField: title,
      subtitleField: subtitle,
      citationTypeField: citationType,
      authorFirstNameField: authorFirstName,
      authorMiddleInitialField: authorMiddleInitial,
      authorLastNameField: authorLastName,
      authorSuffixField: authorSuffix,
      corporateAuthorField: corporateAuthor,
      additionalAuthorsField: additionalAuthors,
      publicationDateField: publicationDate,
      publisherField: publisher,
      publisherLocationField: publisherLocation,
      editionField: edition,
      volumeField: volume,
      issueField: issue,
      seriesTitleField: seriesTitle,
      seriesNumberField: seriesNumber,
      pagesField: pages,
      chapterTitleField: chapterTitle,
      chapterNumberField: chapterNumber,
      urlField: url,
      doiField: doi,
      journalTitleField: journalTitle,
      journalAbbreviationField: journalAbbreviation,
      conferenceNameField: conferenceName,
      conferenceLocationField: conferenceLocation,
      conferenceDateField: conferenceDate,
      degreeTypeField: degreeType,
      universityField: university,
      reportNumberField: reportNumber,
      institutionField: institution,
      patentNumberField: patentNumber,
      patentOfficeField: patentOffice,
      legalCitationField: legalCitation,
      courtField: court,
      caseNameField: caseName,
      abstractField: abstract,
      notesField: notes,
      fullDocumentField: fullDocument,
      mediaField: media,
      'has_been_synced': 1,
      'edits_are_synced': 1,
      'last_modified_timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    // Use upsert to handle both insert and update cases
    await db.insert(
      citationTableName,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    QuizzerLogger.logSuccess('Successfully upserted citation $title from inbound sync.');
  } catch (e) {
    QuizzerLogger.logError('Error upserting citation from inbound sync - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Delete a citation
Future<void> deleteCitation({
  required String title,
  required String subtitle,
  required String publisher,
  required String publicationDate,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Deleting citation: $title');
    await verifyCitationTable(db);
    
    final int result = await db.delete(
      citationTableName,
      where: '$titleField = ? AND $subtitleField = ? AND $publisherField = ? AND $publicationDateField = ?',
      whereArgs: [title, subtitle, publisher, publicationDate],
    );
    
    if (result > 0) {
      QuizzerLogger.logSuccess('Citation $title deleted successfully ($result row affected).');
    } else {
      QuizzerLogger.logWarning('Delete operation for citation $title affected 0 rows. Citation might not exist.');
    }
  } catch (e) {
    QuizzerLogger.logError('Error deleting citation - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Get citations by citation type
Future<List<Map<String, dynamic>>> getCitationsByType(String citationType) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching citations with type: $citationType');
    await verifyCitationTable(db);
    
    // Use the universal query helper
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      citationTableName,
      db,
      where: '$citationTypeField = ?',
      whereArgs: [citationType],
    );

    QuizzerLogger.logValue('Retrieved ${results.length} citations with type $citationType');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting citations by type - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Get citations by author
Future<List<Map<String, dynamic>>> getCitationsByAuthor(String authorLastName) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching citations by author: $authorLastName');
    await verifyCitationTable(db);
    
    // Use the universal query helper
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      citationTableName,
      db,
      where: '$authorLastNameField = ?',
      whereArgs: [authorLastName],
    );

    QuizzerLogger.logValue('Retrieved ${results.length} citations by author $authorLastName');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting citations by author - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Get citations by publisher
Future<List<Map<String, dynamic>>> getCitationsByPublisher(String publisher) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching citations by publisher: $publisher');
    await verifyCitationTable(db);
    
    // Use the universal query helper
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      citationTableName,
      db,
      where: '$publisherField = ?',
      whereArgs: [publisher],
    );

    QuizzerLogger.logValue('Retrieved ${results.length} citations by publisher $publisher');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error getting citations by publisher - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

// Search citations by title (partial match)
Future<List<Map<String, dynamic>>> searchCitationsByTitle(String searchTerm) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Searching citations by title: $searchTerm');
    await verifyCitationTable(db);
    
    // Use the universal query helper with LIKE operator
    final List<Map<String, dynamic>> results = await queryAndDecodeDatabase(
      citationTableName,
      db,
      where: '$titleField LIKE ?',
      whereArgs: ['%$searchTerm%'],
    );

    QuizzerLogger.logValue('Retrieved ${results.length} citations matching title search: $searchTerm');
    return results;
  } catch (e) {
    QuizzerLogger.logError('Error searching citations by title - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Gets the most recent last_modified_timestamp from the citations table.
/// Returns null if no records exist.
Future<String?> getMostRecentCitationTimestamp() async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    QuizzerLogger.logMessage('Fetching most recent citation timestamp');
    await verifyCitationTable(db);
    
    final List<Map<String, dynamic>> results = await db.rawQuery(
      'SELECT last_modified_timestamp FROM $citationTableName WHERE last_modified_timestamp IS NOT NULL ORDER BY last_modified_timestamp DESC LIMIT 1'
    );
    
    if (results.isEmpty) {
      QuizzerLogger.logMessage('No citations found with timestamp');
      return null;
    }
    
    final String timestamp = results.first['last_modified_timestamp'] as String;
    QuizzerLogger.logValue('Most recent citation timestamp: $timestamp');
    return timestamp;
  } catch (e) {
    QuizzerLogger.logError('Error getting most recent citation timestamp - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
}

/// Validates citation data based on citation type requirements.
/// Returns true if all required fields for the given citation type are present.
/// Returns false if any required fields are missing.
bool validateCitationData(Map<String, dynamic> citationData) {
  final String? citationType = citationData[citationTypeField];
  final String? title = citationData[titleField];
  final String? authorFirstName = citationData[authorFirstNameField];
  final String? authorLastName = citationData[authorLastNameField];
  final String? publicationDate = citationData[publicationDateField];
  final String? publisher = citationData[publisherField];
  final String? fullDocument = citationData[fullDocumentField];
  
  // Check universal required fields for all citation types
  if (title == null || title.isEmpty) {
    QuizzerLogger.logWarning('Citation validation failed: title is required for all citation types');
    return false;
  }
  
  if (citationType == null || citationType.isEmpty) {
    QuizzerLogger.logWarning('Citation validation failed: citation_type is required for all citation types');
    return false;
  }
  
  if (publicationDate == null || publicationDate.isEmpty) {
    QuizzerLogger.logWarning('Citation validation failed: publication_date is required for all citation types');
    return false;
  }
  
  if (publisher == null || publisher.isEmpty) {
    QuizzerLogger.logWarning('Citation validation failed: publisher is required for all citation types');
    return false;
  }
  
  if (fullDocument == null || fullDocument.isEmpty) {
    QuizzerLogger.logWarning('Citation validation failed: full_document is required for all citation types');
    return false;
  }
  
  // Check author requirements (individual author is required)
  if (authorFirstName == null || authorFirstName.isEmpty || authorLastName == null || authorLastName.isEmpty) {
    QuizzerLogger.logWarning('Citation validation failed: both author_first_name and author_last_name are required for all citation types');
    return false;
  }
  
  // Check citation type specific requirements
  switch (citationType.toLowerCase()) {
    case 'book':
      // For books, we cite specific chapters and pages, not the whole book
      final String? chapterTitle = citationData[chapterTitleField];
      final String? chapterNumber = citationData[chapterNumberField];
      final String? pages = citationData[pagesField];
      
      if (chapterTitle == null || chapterTitle.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: chapter_title is required for Book citations');
        return false;
      }
      if (chapterNumber == null || chapterNumber.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: chapter_number is required for Book citations');
        return false;
      }
      if (pages == null || pages.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: pages is required for Book citations');
        return false;
      }
      
      // publisher_location is highly recommended for complete citations
      final String? publisherLocation = citationData[publisherLocationField];
      if (publisherLocation == null || publisherLocation.isEmpty) {
        QuizzerLogger.logWarning('Citation validation warning: publisher_location is highly recommended for Book citations');
        // Not returning false as it's only "highly recommended", not strictly required
      }
      break;
      
    case 'journal article':
      final String? journalTitle = citationData[journalTitleField];
      final String? volume = citationData[volumeField];
      final String? issue = citationData[issueField];
      final String? pages = citationData[pagesField];
      
      if (journalTitle == null || journalTitle.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: journal_title is required for Journal Article citations');
        return false;
      }
      if (volume == null || volume.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: volume is required for Journal Article citations');
        return false;
      }
      if (issue == null || issue.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: issue is required for Journal Article citations');
        return false;
      }
      if (pages == null || pages.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: pages is required for Journal Article citations');
        return false;
      }
      break;
      
    case 'website':
      final String? url = citationData[urlField];
      if (url == null || url.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: url is required for Website citations');
        return false;
      }
      break;
      
    case 'conference paper':
      final String? conferenceName = citationData[conferenceNameField];
      final String? conferenceLocation = citationData[conferenceLocationField];
      final String? conferenceDate = citationData[conferenceDateField];
      
      if (conferenceName == null || conferenceName.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: conference_name is required for Conference Paper citations');
        return false;
      }
      if (conferenceLocation == null || conferenceLocation.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: conference_location is required for Conference Paper citations');
        return false;
      }
      if (conferenceDate == null || conferenceDate.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: conference_date is required for Conference Paper citations');
        return false;
      }
      break;
      
    case 'thesis':
      final String? degreeType = citationData[degreeTypeField];
      final String? university = citationData[universityField];
      
      if (degreeType == null || degreeType.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: degree_type is required for Thesis citations');
        return false;
      }
      if (university == null || university.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: university is required for Thesis citations');
        return false;
      }
      break;
      
    case 'dissertation':
      final String? degreeType = citationData[degreeTypeField];
      final String? university = citationData[universityField];
      
      if (degreeType == null || degreeType.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: degree_type is required for Dissertation citations');
        return false;
      }
      if (university == null || university.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: university is required for Dissertation citations');
        return false;
      }
      break;
      
    case 'report':
      final String? institution = citationData[institutionField];
      
      if (institution == null || institution.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: institution is required for Report citations');
        return false;
      }
      break;
      
    case 'patent':
      final String? patentNumber = citationData[patentNumberField];
      final String? patentOffice = citationData[patentOfficeField];
      
      if (patentNumber == null || patentNumber.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: patent_number is required for Patent citations');
        return false;
      }
      if (patentOffice == null || patentOffice.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: patent_office is required for Patent citations');
        return false;
      }
      break;
      
    case 'legislation':
      final String? legalCitation = citationData[legalCitationField];
      
      if (legalCitation == null || legalCitation.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: legal_citation is required for Legislation citations');
        return false;
      }
      break;
      
    case 'legal document':
      final String? legalCitation = citationData[legalCitationField];
      final String? court = citationData[courtField];
      final String? caseName = citationData[caseNameField];
      
      // At least one of: legal_citation, or a combination of case_name and court
      if ((legalCitation == null || legalCitation.isEmpty) && 
          ((caseName == null || caseName.isEmpty) || (court == null || court.isEmpty))) {
        QuizzerLogger.logWarning('Citation validation failed: either legal_citation OR both case_name and court are required for Legal Document citations');
        return false;
      }
      break;
      
    case 'artwork':
      // publisher_location and media are required
      final String? publisherLocation = citationData[publisherLocationField];
      final List<String>? media = citationData[mediaField];
      
      if (publisherLocation == null || publisherLocation.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: publisher_location is required for Artwork citations');
        return false;
      }
      if (media == null || media.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: media is required for Artwork citations');
        return false;
      }
      break;
      
    case 'interview':
      // publisher (interviewer/host) and publisher_location are required
      final String? interviewLocation = citationData[publisherLocationField];
      if (interviewLocation == null || interviewLocation.isEmpty) {
        QuizzerLogger.logWarning('Citation validation failed: publisher_location is required for Interview citations');
        return false;
      }
      break;
      
    default:
      QuizzerLogger.logWarning('Citation validation warning: unknown citation type "$citationType", skipping type-specific validation');
      break;
  }
  
  QuizzerLogger.logSuccess('Citation validation passed for type: $citationType');
  return true;
}

/// True batch upsert for citations using a single SQL statement
Future<void> batchUpsertCitations({
  required List<Map<String, dynamic>> records,
  int chunkSize = 500,
}) async {
  try {
    final db = await getDatabaseMonitor().requestDatabaseAccess();
    if (db == null) {
      throw Exception('Failed to acquire database access');
    }
    if (records.isEmpty) return;
    QuizzerLogger.logMessage('Starting TRUE batch upsert for citations: ${records.length} records');
    await verifyCitationTable(db);

    // List of all columns in the table
    final columns = [
      'title',
      'subtitle',
      'citation_type',
      'author_first_name',
      'author_middle_initial',
      'author_last_name',
      'author_suffix',
      'corporate_author',
      'additional_authors',
      'publication_date',
      'publisher',
      'publisher_location',
      'edition',
      'volume',
      'issue',
      'series_title',
      'series_number',
      'pages',
      'chapter_title',
      'chapter_number',
      'url',
      'doi',
      'journal_title',
      'journal_abbreviation',
      'conference_name',
      'conference_location',
      'conference_date',
      'degree_type',
      'university',
      'report_number',
      'institution',
      'patent_number',
      'patent_office',
      'legal_citation',
      'court',
      'case_name',
      'abstract',
      'notes',
      'full_document',
      'media',
      'has_been_synced',
      'edits_are_synced',
      'last_modified_timestamp',
    ];

    // Helper to get value or null/default
    dynamic getVal(Map<String, dynamic> r, String k, dynamic def) => r[k] ?? def;

    for (int i = 0; i < records.length; i += chunkSize) {
      final batch = records.sublist(i, i + chunkSize > records.length ? records.length : i + chunkSize);
      final values = <dynamic>[];
      final valuePlaceholders = batch.map((r) {
        for (final col in columns) {
          values.add(getVal(r, col, null));
        }
        return '(${List.filled(columns.length, '?').join(',')})';
      }).join(', ');

      // Use composite primary key for upsert
      final updateSet = columns.where((c) => !['title', 'subtitle', 'publisher', 'publication_date'].contains(c)).map((c) => '$c=excluded.$c').join(', ');
      final sql = 'INSERT INTO citations (${columns.join(',')}) VALUES $valuePlaceholders ON CONFLICT(title, subtitle, publisher, publication_date) DO UPDATE SET $updateSet;';
      await db.rawInsert(sql, values);
    }
    QuizzerLogger.logSuccess('TRUE batch upsert for citations complete.');
  } catch (e) {
    QuizzerLogger.logError('Error batch upserting citations - $e');
    rethrow;
  } finally {
    getDatabaseMonitor().releaseDatabaseAccess();
  }
} 
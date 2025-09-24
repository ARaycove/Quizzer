import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/05_ml_modeling/attempt_pre_process.dart';
import 'test_helpers.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Manual iteration variable for reusing accounts across tests
  late int testIteration;
  
  // Test credentials - defined once and reused
  late String testEmail;
  late String testPassword;
  late String testAccessPassword;
  
  // Global instances used across tests
  late final SessionManager sessionManager;
  
  setUpAll(() async {
    await QuizzerLogger.setupLogging();
    HttpOverrides.global = null;
    
    // Load test configuration
    final config = await getTestConfig();
    testIteration = config['testIteration'] as int;
    testPassword = config['testPassword'] as String;
    testAccessPassword = config['testAccessPassword'] as String;
    
    // Set up test credentials
    testEmail = 'test_user_$testIteration@example.com';
    
    sessionManager = getSessionManager();
    await sessionManager.initializationComplete;
    
    // Perform full login initialization (excluding sync workers for testing)
    final loginResult = await loginInitialization(
      email: testEmail, 
      password: testPassword, 
      supabase: sessionManager.supabase, 
      storage: sessionManager.getBox(testAccessPassword),
      testRun: true, // This bypasses sync workers for faster testing
    );
    
    expect(loginResult['success'], isTrue, reason: 'Login initialization should succeed');
    QuizzerLogger.logSuccess('Full login initialization completed successfully');
  });
  
  test('Load, decode, and unpack question answer attempts', () async {
    // Configuration for field display
    const int fieldsPerLine = 3; // Change this to adjust fields per line
    const int fieldNameWidth = 40;   // Space for field name
    const int fieldValueWidth = 9;   // Space for field value
    
    // === STEP 1: Load DataFrame from Supabase ===
    QuizzerLogger.logMessage('=== STEP 1: Loading DataFrame from Supabase ===');
    final rawDataFrame = await loadQuestionAnswerAttemptsFromSupabase(limit: 5);
    QuizzerLogger.logSuccess('Loaded ${rawDataFrame.rows.length} rows x ${rawDataFrame.header.length} columns');
    
    // === STEP 2: Convert DataFrame with JSON decoding ===
    QuizzerLogger.logMessage('=== STEP 2: Converting DataFrame with JSON decoding ===');
    final decodedDataFrame = await decodeDataFrameJsonFields(rawDataFrame);
    QuizzerLogger.logSuccess('Decoded ${decodedDataFrame.rows.length} rows x ${decodedDataFrame.header.length} columns');
    
    // === STEP 3: Unpack DataFrame features ===
    QuizzerLogger.logMessage('=== STEP 3: Unpacking DataFrame features ===');
    final unpackedDataFrame = await unpackDataFrameFeatures(decodedDataFrame);
    QuizzerLogger.logSuccess('Unpacked to ${unpackedDataFrame.rows.length} rows x ${unpackedDataFrame.header.length} columns');
    
    if (unpackedDataFrame.rows.isNotEmpty) {
      print('\n=== UNPACKED DATAFRAME FIRST RECORD ANALYSIS ===');
      final firstUnpackedRow = unpackedDataFrame.rows.first.toList();
      final unpackedHeaders = unpackedDataFrame.header.toList();
      
      print('Total features: ${unpackedHeaders.length}');
      print('');
      
      // === FIXED PRINT SECTION ===
      // Collect only visible fields
      final List<MapEntry<String, dynamic>> visibleFields = [];
      for (int j = 0; j < unpackedHeaders.length; j++) {
        final fieldName = unpackedHeaders[j];
        if (fieldName.startsWith("q_v_")) continue; // skip entirely
        final fieldValue = j < firstUnpackedRow.length ? firstUnpackedRow[j] : 'null';
        visibleFields.add(MapEntry(fieldName, fieldValue));
      }
      
      // Print in rows of fieldsPerLine
      for (int i = 0; i < visibleFields.length; i += fieldsPerLine) {
        final endIndex = (i + fieldsPerLine < visibleFields.length)
            ? i + fieldsPerLine
            : visibleFields.length;
        final rowFields = visibleFields.sublist(i, endIndex);
        
        final line = rowFields.map((entry) {
          final fieldName = entry.key;
          final fieldValue = entry.value;
          
          // Truncate field name
          String truncatedName;
          if (fieldName.length > fieldNameWidth) {
            truncatedName = fieldName.substring(0, fieldNameWidth - 3) + '...';
          } else {
            truncatedName = fieldName.padRight(fieldNameWidth);
          }
          
          // Truncate field value
          final valueString = fieldValue?.toString() ?? 'null';
          String truncatedValue;
          if (valueString.length > fieldValueWidth) {
            truncatedValue = valueString.substring(0, fieldValueWidth - 3) + '...';
          } else {
            truncatedValue = valueString.padLeft(fieldValueWidth);
          }
          
          return '$truncatedName:$truncatedValue';
        }).join('|');
        
        print('$line|');
        print('');
      }
    }
    
    print('=== UNPACKING ANALYSIS COMPLETE ===');
  });
}

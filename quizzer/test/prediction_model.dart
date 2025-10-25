import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/05_ml_modeling/attempt_pre_process.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/ml_models_table.dart';
import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart';
import 'package:quizzer/backend_systems/05_ml_modeling/accuracy_net.dart';
import 'test_helpers.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  
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
    testPassword = "Starting11Over!";
    testAccessPassword = config['testAccessPassword'] as String;
    
    // Set up test credentials
    testEmail = 'aacra0820@gmail.com';
    
    sessionManager = getSessionManager();
    await sessionManager.initializationComplete;
    
    // Perform full login initialization (excluding sync workers for testing)
    final loginResult = await loginInitialization(
      email: testEmail, 
      password: testPassword, 
      supabase: sessionManager.supabase, 
      storage: sessionManager.getBox(testAccessPassword),
      testRun: false, // This bypasses sync workers for faster testing
    );
    
    expect(loginResult['success'], isTrue, reason: 'Login initialization should succeed');
    QuizzerLogger.logMessage('Full login initialization completed successfully');
  });
  

  test('Load Training Data, Process Training Data, and Run test on imported model', () async {
    final startTime = DateTime.now();
    
    // === STEP 1: Fetch batch inference samples ===
    QuizzerLogger.logMessage('=== STEP 1: Fetching batch inference samples ===');
    final fetchResult = await fetchBatchInferenceSamples(nRecords: 5, kMinutes: 60);
    final primaryKeysFrame = fetchResult['primary_keys']!;
    final rawDataFrame = fetchResult['raw_inference_data']!;
    QuizzerLogger.logMessage('Loaded ${rawDataFrame.rows.length} rows x ${rawDataFrame.header.length} columns');
    QuizzerLogger.logMessage('Primary keys: ${primaryKeysFrame.rows.length} rows x ${primaryKeysFrame.header.length} columns');
    
    // === STEP 2: Convert DataFrame with JSON decoding ===
    QuizzerLogger.logMessage('=== STEP 2: Converting DataFrame with JSON decoding ===');
    final decodedDataFrame = await decodeDataFrameJsonFields(rawDataFrame);
    QuizzerLogger.logMessage('Decoded ${decodedDataFrame.rows.length} rows x ${decodedDataFrame.header.length} columns');

    // Check question_vector after decoding
    final decodedHeaders = decodedDataFrame.header.toList();
    final decodedRows = decodedDataFrame.rows.toList();
    final qvIndex = decodedHeaders.indexOf('question_vector');
    if (qvIndex != -1 && decodedRows.isNotEmpty) {
      final firstRowQV = decodedRows[0].toList()[qvIndex];
      QuizzerLogger.logMessage('question_vector after decoding - Type: ${firstRowQV.runtimeType}');
      if (firstRowQV is List) {
        QuizzerLogger.logMessage('question_vector length: ${firstRowQV.length}');
        QuizzerLogger.logMessage('question_vector first 5 values: ${firstRowQV.take(5).toList()}');
      } else {
        QuizzerLogger.logWarning('question_vector is NOT a List: $firstRowQV');
      }
    }

    // === STEP 3: Unpack DataFrame features ===  
    QuizzerLogger.logMessage('=== STEP 3: Unpacking DataFrame features ===');
    final unpackedDataFrame = await unpackDataFrameFeatures(decodedDataFrame);
    QuizzerLogger.logMessage('Unpacked to ${unpackedDataFrame.rows.length} rows x ${unpackedDataFrame.header.length} columns');
    
    // === STEP 4: One-hot encode categorical features ===
    QuizzerLogger.logMessage('=== STEP 4: One-hot encoding categorical features ===');
    final encodedDataFrame = await oneHotEncodeDataFrame(unpackedDataFrame);
    QuizzerLogger.logMessage('Encoded to ${encodedDataFrame.rows.length} rows x ${encodedDataFrame.header.length} columns');

    // Write complete feature mapping to JSON file
    QuizzerLogger.logMessage('Writing encoded features to JSON file for analysis...');
    final encodedHeaders = encodedDataFrame.header.toList();
    final encodedRows = encodedDataFrame.rows.toList();
    
    final Map<String, dynamic> featureData = {
      'num_features': encodedHeaders.length,
      'num_samples': encodedRows.length,
      'headers': encodedHeaders,
      'sample_row_0': {},
    };
    
    // Add first row values
    final firstEncodedRow = encodedRows[0].toList();
    for (int i = 0; i < encodedHeaders.length; i++) {
      featureData['sample_row_0'][encodedHeaders[i]] = firstEncodedRow[i];
    }
    
    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(featureData);
    final file = File('encoded_features_debug.json');
    await file.writeAsString(jsonString);
    QuizzerLogger.logSuccess('Wrote encoded features to: ${file.absolute.path}');

    // === STEP 5: Transform to match model input shape ===
    QuizzerLogger.logMessage('=== STEP 5: Transforming DataFrame to match accuracy_net input shape ===');
    final inferenceFrame = await transformDataFrameToAccuracyNetInputShape(encodedDataFrame);
    QuizzerLogger.logMessage('Transformed to inference: ${inferenceFrame.rows.length} rows x ${inferenceFrame.header.length} columns');

    // Print first 10 columns for first 5 rows
    QuizzerLogger.logMessage('=== First 10 columns head (first 5 rows) ===');
    final headers = inferenceFrame.header.toList();
    final rows = inferenceFrame.rows.toList();
    
    QuizzerLogger.logMessage('Headers: ${headers.sublist(0, 10).join(", ")}');
    for (int i = 0; i < 5 && i < rows.length; i++) {
      final rowValues = rows[i].toList();
      QuizzerLogger.logMessage('Row $i: ${rowValues.sublist(0, 10).join(", ")}');
    }

    // === STEP 6: Validate feature order matches input map ===
    QuizzerLogger.logMessage('=== STEP 6: Validating feature order matches input map ===');
    final modelRecord = await getMlModel('accuracy_net');
    expect(modelRecord, isNotNull, reason: 'accuracy_net model should exist in ml_models table');
    
    final dynamic inputFeaturesData = modelRecord!['input_features'];
    final Map<String, dynamic> featureMap = inputFeaturesData is String 
        ? decodeValueFromDB(inputFeaturesData) as Map<String, dynamic>
        : inputFeaturesData as Map<String, dynamic>;
    
    final sortedEntries = featureMap.entries.toList()
      ..sort((a, b) {
        final posA = (a.value as Map<String, dynamic>)['pos'] as int;
        final posB = (b.value as Map<String, dynamic>)['pos'] as int;
        return posA.compareTo(posB);
      });
    
    final expectedFeatureOrder = sortedEntries.map((e) => e.key).toList();
    final actualFeatureOrder = inferenceFrame.header.toList();
    
    QuizzerLogger.logMessage('Expected input map features: ${expectedFeatureOrder.length}');
    QuizzerLogger.logMessage('Actual transformed DataFrame features: ${actualFeatureOrder.length}');
    QuizzerLogger.logMessage('Inference DataFrame shape: ${inferenceFrame.rows.length} rows x ${inferenceFrame.header.length} columns');
    QuizzerLogger.logMessage('Primary keys DataFrame shape: ${primaryKeysFrame.rows.length} rows x ${primaryKeysFrame.header.length} columns');
    
    expect(actualFeatureOrder.length, equals(expectedFeatureOrder.length), 
      reason: 'Transformed DataFrame should have same number of features as input map. Expected: ${expectedFeatureOrder.length}, Got: ${actualFeatureOrder.length}');
    
    for (int i = 0; i < expectedFeatureOrder.length; i++) {
      expect(actualFeatureOrder[i], equals(expectedFeatureOrder[i]),
        reason: 'Feature at position $i should be ${expectedFeatureOrder[i]} but got ${actualFeatureOrder[i]}');
    }
    
    expect(primaryKeysFrame.rows.length, equals(inferenceFrame.rows.length),
      reason: 'Primary keys and inference data should have same number of rows');
    
    QuizzerLogger.logMessage('Feature order validation passed - all ${expectedFeatureOrder.length} features match expected order');
    QuizzerLogger.logMessage('Shape validation passed - DataFrame has correct dimensions for model input');
    QuizzerLogger.logMessage('Primary keys alignment validated - ${primaryKeysFrame.rows.length} rows match inference data');
    
    // === STEP 7: Load accuracy_net model ===
    QuizzerLogger.logMessage('=== STEP 7: Loading accuracy_net TFLite model ===');
    final interpreter = await loadAccuracyNetModel();
    QuizzerLogger.logMessage('Model loaded successfully');
    
    // === STEP 8: Run batch inference ===
    QuizzerLogger.logMessage('=== STEP 8: Running batch inference ===');
    final resultsFrame = await runBatchInference(
      interpreter: interpreter,
      primaryKeysFrame: primaryKeysFrame,
      inputFrame: inferenceFrame,
    );
    QuizzerLogger.logMessage('Inference completed: ${resultsFrame.rows.length} predictions generated');
    QuizzerLogger.logMessage('Results frame shape: ${resultsFrame.rows.length} rows x ${resultsFrame.header.length} columns');
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    QuizzerLogger.logMessage('=== TOTAL PIPELINE EXECUTION TIME: ${duration.inMilliseconds}ms (${duration.inSeconds}s) ===');

    // === STEP 9: Display primary keys DataFrame contents ===
    QuizzerLogger.logMessage('=== STEP 9: Primary Keys DataFrame Contents ===');
    QuizzerLogger.logMessage('Headers: ${resultsFrame.header.toList()}');
    final resultRows = resultsFrame.rows.toList();
    for (int i = 0; i < resultRows.length; i++) {
      final row = resultRows[i].toList();
      QuizzerLogger.logMessage('Row $i: $row');
    }
    
    interpreter.close();
    

  });
}
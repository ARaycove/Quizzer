import 'package:flutter_test/flutter_test.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/02_login_authentication/login_initialization.dart';
import 'package:quizzer/backend_systems/05_ml_modeling/attempt_pre_process.dart';
import 'package:quizzer/backend_systems/05_ml_modeling/xgboost_model.dart';
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
  
  test('Load, process, balance, and split data for model training', () async {
    // === STEP 1: Load DataFrame from Supabase ===
    QuizzerLogger.logMessage('=== STEP 1: Loading DataFrame from Supabase ===');
    final rawDataFrame = await loadQuestionAnswerAttemptsFromSupabase();
    QuizzerLogger.logSuccess('Loaded ${rawDataFrame.rows.length} rows x ${rawDataFrame.header.length} columns');
    
    // === STEP 2: Convert DataFrame with JSON decoding ===
    QuizzerLogger.logMessage('=== STEP 2: Converting DataFrame with JSON decoding ===');
    final decodedDataFrame = await decodeDataFrameJsonFields(rawDataFrame);
    QuizzerLogger.logSuccess('Decoded ${decodedDataFrame.rows.length} rows x ${decodedDataFrame.header.length} columns');
    
    // === STEP 3: Unpack DataFrame features ===  
    QuizzerLogger.logMessage('=== STEP 3: Unpacking DataFrame features ===');
    final unpackedDataFrame = await unpackDataFrameFeatures(decodedDataFrame);
    QuizzerLogger.logSuccess('Unpacked to ${unpackedDataFrame.rows.length} rows x ${unpackedDataFrame.header.length} columns');
    
    // === STEP 4: One-hot encode categorical features ===
    QuizzerLogger.logMessage('=== STEP 4: One-hot encoding categorical features ===');
    final encodedDataFrame = await oneHotEncodeDataFrame(unpackedDataFrame);
    QuizzerLogger.logSuccess('Encoded to ${encodedDataFrame.rows.length} rows x ${encodedDataFrame.header.length} columns');
    
    // === STEP 5: Impute missing values ===
    QuizzerLogger.logMessage('=== STEP 5: Imputing missing values ===');
    final imputedDataFrame = imputeMissingValues(encodedDataFrame);
    QuizzerLogger.logSuccess('Imputed to ${imputedDataFrame.rows.length} rows x ${imputedDataFrame.header.length} columns');
    
    // === STEP 6: Split data into train/test sets ===
    QuizzerLogger.logMessage('=== STEP 6: Splitting data into train/test sets ===');
    final splits = trainTestSplit(
      dataFrame: imputedDataFrame,
      targetColumn: 'response_result',
      testSize: 0.2,
      shuffle: true,
    );
    
    var xTrain = splits['X_train']!;
    final xTest = splits['X_test']!;
    var yTrain = splits['y_train']!;
    final yTest = splits['y_test']!;
    
    QuizzerLogger.logSuccess('Split complete:');
    QuizzerLogger.logMessage('X_train: ${xTrain.rows.length} rows x ${xTrain.header.length} features');
    QuizzerLogger.logMessage('X_test: ${xTest.rows.length} rows x ${xTest.header.length} features');
    QuizzerLogger.logMessage('y_train: ${yTrain.rows.length} rows');
    QuizzerLogger.logMessage('y_test: ${yTest.rows.length} rows');
    
    // === STEP 7: Balance training dataset ===
    QuizzerLogger.logMessage('=== STEP 7: Balancing training dataset ===');
    final balancedData = balanceDataset(
      xTrain: xTrain,
      yTrain: yTrain,
    );
    
    xTrain = balancedData['X_balanced']!;
    yTrain = balancedData['y_balanced']!;
    
    // === STEP 8: Initialize and fit XGBoost model ===
    QuizzerLogger.logMessage('=== STEP 8: Training XGBoost model ===');
    final model = XGBoostModel(
      minLeaf: 1,
      depth: 6,
      boostingRounds: 10,
    );
    model.fit(xTrain, yTrain);
    QuizzerLogger.logSuccess('XGBoost model training completed');


    // === Step 9: Assess Model on Test Set ===
    Map<String, dynamic> metrics = model.assessAll(xTest, yTest);
    // Log all metrics
    QuizzerLogger.logMessage('=== MODEL PERFORMANCE METRICS ===');
    QuizzerLogger.logMessage('Accuracy: ${metrics['accuracy']?.toStringAsFixed(4)}');
    QuizzerLogger.logMessage('Precision: ${metrics['precision']?.toStringAsFixed(4)}');
    QuizzerLogger.logMessage('Recall: ${metrics['recall']?.toStringAsFixed(4)}');
    QuizzerLogger.logMessage('F1 Score: ${metrics['f1_score']?.toStringAsFixed(4)}');
    QuizzerLogger.logMessage('Log Loss: ${metrics['log_loss']?.toStringAsFixed(4)}');
    QuizzerLogger.logMessage('=== END METRICS ===');
    // Calculate and log confusion matrix
    final confusionMatrix = model.calculateConfusionMatrix(xTest, yTest);
    QuizzerLogger.logMessage('=== CONFUSION MATRIX ===');
    QuizzerLogger.logMessage('True Negatives (predicted wrong, actually wrong): ${confusionMatrix[0]}');
    QuizzerLogger.logMessage('False Positives (predicted right, actually wrong): ${confusionMatrix[1]}');
    QuizzerLogger.logMessage('False Negatives (predicted wrong, actually right): ${confusionMatrix[2]}');
    QuizzerLogger.logMessage('True Positives (predicted right, actually right): ${confusionMatrix[3]}');
    QuizzerLogger.logMessage('=== END CONFUSION MATRIX ===');

    // Calculate specificity (ability to identify wrong answers)
    final tn = confusionMatrix[0];
    final fp = confusionMatrix[1];
    final specificity = tn + fp > 0 ? tn / (tn + fp) : 0.0;
    QuizzerLogger.logMessage('Specificity (correctly identifying wrong answers): ${specificity.toStringAsFixed(4)}');
    // === Step 10: If favorable save the model and push to supabase ===
    
  });
}
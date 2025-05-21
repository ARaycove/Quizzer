// import 'dart:io';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:llama_cpp_dart/llama_cpp_dart.dart';
// import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
// import 'package:path/path.dart' as p;
// import 'package:logging/logging.dart';

// void main() {
//   TestWidgetsFlutterBinding.ensureInitialized();
//   QuizzerLogger.setupLogging(level: Level.INFO);

//   String getLlamaLibPath() {
//     if (Platform.isLinux) return 'libllama.so';
//     if (Platform.isMacOS) return 'libllama.dylib';
//     if (Platform.isWindows) return 'llama.dll';
//     throw UnsupportedError('Unsupported platform for Llama.libraryPath');
//   }

//   try {
//     Llama.libraryPath = getLlamaLibPath();
//     QuizzerLogger.logMessage("Attempting to use Llama library path: ${Llama.libraryPath}");
//   } catch (e) {
//     QuizzerLogger.logError(
//         "CRITICAL: Could not set Llama.libraryPath. Ensure the native library is correctly built and accessible. Error: $e");
//   }

//   group('Basic Llama.cpp Dart Test', () {
//     test('Model responds to a simple prompt', () {
//       final String projectRoot = Directory.current.path;
//       final String actualProjectRoot = p.basename(projectRoot) == 'quizzer' ? projectRoot : p.join(projectRoot, 'quizzer');
//       final String baseModelPath = p.join(actualProjectRoot, 'runtime_cache', 'models', 'moondream2-text-model-f16.gguf');

//       if (!File(baseModelPath).existsSync()) {
//         final errorMsg = 'Base model file not found: $baseModelPath. CWD: ${Directory.current.path}';
//         QuizzerLogger.logError(errorMsg);
//         fail(errorMsg);
//       }

//       Llama? llamaInstance; // Declare it here so it's accessible

//       try {
//         final modelParams = ModelParams();
//         final contextParams = ContextParams();
//         llamaInstance = Llama(baseModelPath, modelParams, contextParams); // Initialize
//         QuizzerLogger.logSuccess('Llama instance initialized with text model.');
//       } catch (e, s) {
//         QuizzerLogger.logError('Error during Llama initialization: $e');
//         QuizzerLogger.logError('Stack trace: $s');
//         fail('Llama initialization failed: $e');
//       }

//       const String promptText = "USER: What is the capital of France?\nASSISTANT:";
//       QuizzerLogger.logMessage('Prompting model with: $promptText');

//       try {
//         final stopwatch = Stopwatch()..start();
//         llamaInstance.setPrompt(promptText); // Use the local variable
//         final StringBuffer buffer = StringBuffer();
//         int tokensProcessed = 0;
//         const maxTokensToProcess = 100;

//         QuizzerLogger.logMessage('Streaming tokens...');
//         while (tokensProcessed < maxTokensToProcess) {
//           var (token, done) = llamaInstance.getNext();
//           if (token.isNotEmpty) {
//             buffer.write(token);
//           }
//           if (done) {
//             QuizzerLogger.logMessage('Model indicated completion (done flag).');
//             break;
//           }
//           tokensProcessed++;
//         }

//         final String result = buffer.toString().trim();
//         stopwatch.stop();
//         QuizzerLogger.logSuccess(
//             'Model response processing completed in ${stopwatch.elapsedMilliseconds}ms.');
//         QuizzerLogger.logMessage('Model Reconstructed Response:');
//         QuizzerLogger.logValue(result);

//         expect(result.isNotEmpty, isTrue,
//             reason: "Model should return a non-empty response.");
//         expect(result.toLowerCase().contains('paris'), isTrue,
//             reason:
//                 "Response should contain 'Paris' for the capital of France.");
//       } catch (e, s) {
//         QuizzerLogger.logError('Error during model prompting: $e');
//         QuizzerLogger.logError('Stack trace for prompting error: $s');
//         fail('Model prompting failed: $e');
//       } finally {
//         llamaInstance?.dispose(); // Dispose in a finally block
//       }
//     }, timeout: const Timeout(Duration(minutes: 3)));
//   });
// }

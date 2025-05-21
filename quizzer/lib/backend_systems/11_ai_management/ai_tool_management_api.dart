import 'dart:io'; // For File, Directory, Process, FileSystemEntity, FileSystemException, Platform
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:http/http.dart' as http;

// --- 1. General AI Call ---

/// Internal placeholder for selecting an AI model and executing the call.
///
/// This function would contain the logic to:
/// 1. Select an appropriate AI model/service (e.g., local Ollama, Gemini, Claude)
///    based on availability, configuration, the nature of the prompt, or attachments.
/// 2. Prepare the request for the selected AI (format prompt, handle attachments).
/// 3. Call the AI service.
/// 4. Parse and return the AI's response.
///
/// For now, it's a non-functional placeholder.
Future<String> _chooseAIModelAndExecute({
  required String prompt,
  List<File>? attachments,
  // Potentially other parameters: preferredModel, specificConfigs, etc.
}) async {
  QuizzerLogger.logMessage('AI Tool Lib: Choosing AI model for prompt: "${prompt.substring(0, prompt.length > 50 ? 50 : prompt.length)}..."');
  if (attachments != null && attachments.isNotEmpty) {
    QuizzerLogger.logMessage('AI Tool Lib: With ${attachments.length} attachments.');
    for (var attachment in attachments) {
      QuizzerLogger.logMessage('AI Tool Lib: Attachment: ${attachment.path}');
    }
  }
  // TODO: Implement actual logic to select and call an AI model.
  QuizzerLogger.logWarning('_chooseAIModelAndExecute is a placeholder and not yet implemented.');
  throw UnimplementedError(
      '_chooseAIModelAndExecute: AI model selection and execution logic is not implemented.');
}

/// Makes a general call to an AI model with the given text prompt and optional file attachments.
///
/// This function abstracts the selection of the specific AI model and handles the interaction.
/// It relies on the internal [_chooseAIModelAndExecute] function to perform the actual AI call.
///
/// - [prompt]: The text prompt to send to the AI.
/// - [attachments]: An optional list of [File] objects to include with the prompt.
///
/// Returns the raw text response from the AI model as a [Future<String>].
/// Throws an error if the AI call fails or if the underlying selection logic fails.
Future<String> callGeneralAI({
  required String prompt,
  List<File>? attachments,
}) async {
  final String logPrompt = prompt.length > 100 ? '${prompt.substring(0, 97)}...' : prompt;
  QuizzerLogger.logMessage('AI Tool Lib: General AI call initiated. Prompt: "$logPrompt"');
  // Delegate to the internal function that handles model selection and execution
  return await _chooseAIModelAndExecute(
    prompt: prompt,
    attachments: attachments,
  );
}

// --- 2. Agent Tool Call Implementations (inspired by ampcode.com article) ---
// These are the actual functions that an agent's tool execution loop would call
// after parsing an LLM's tool usage request (e.g., "tool: read_file({\"path\":\"file.txt\"})").

/// Reads the content of a file at the given [path].
///
/// Corresponds to an agent's interpretation of an LLM requesting `read_file({"path":"..."})`.
///
/// - [path]: The path to the file to read.
///
/// Returns the content of the file as a [Future<String>].
/// Throws a [FileSystemException] if the file is not found or cannot be read.
Future<String> readFileTool({required String path}) async {
  QuizzerLogger.logMessage('AI Tool Lib: Executing readFileTool for path: "$path"');
  final file = File(path);
  if (!await file.exists()) {
    final errorMsg = 'AI Tool Lib: File not found at path: $path';
    QuizzerLogger.logError(errorMsg); // This logError might be re-evaluated based on guidelines if errors always propagate
    throw FileSystemException(errorMsg, path);
  }
  return await file.readAsString();
}

/// Edits a file at the given [path].
///
/// Corresponds to an agent's interpretation of an LLM requesting
/// `edit_file({"path":"...", "old_str":"...", "new_str":"..."})`.
///
/// - If [oldString] is null or empty, [newString] creates or overwrites the file.
/// - If [oldString] is provided and non-empty, its first occurrence in the file
///   is replaced with [newString]. If [oldString] is not found, the file is not
///   modified, and the function returns `false`.
///
/// - [path]: The path to the file to edit.
/// - [oldString]: The existing string to be replaced. If null or empty, [newString] overwrites/creates the file.
/// - [newString]: The new string to write or replace with.
///
/// Returns `true` if the file was successfully written/modified. Returns `false`
/// if [oldString] was provided but not found in the file.
/// Throws an error for other I/O issues.
Future<bool> editFileTool({
  required String path,
  String? oldString,
  required String newString,
}) async {
  QuizzerLogger.logMessage('AI Tool Lib: Executing editFileTool for path: "$path"');
  final file = File(path);
  if (oldString == null || oldString.isEmpty) {
    // Create or overwrite file with newString
    await file.writeAsString(newString, flush: true);
    QuizzerLogger.logMessage('AI Tool Lib: File "$path" created/overwritten.');
  } else {
    // Read, replace, write for existing oldString
    if (!await file.exists()) {
      final errorMsg = 'AI Tool Lib: File not found at path "$path" for targeted edit with oldString.';
      QuizzerLogger.logError(errorMsg); // Re-evaluate
      throw FileSystemException(errorMsg, path);
    }
    String content = await file.readAsString();
    if (content.contains(oldString)) {
      String newContent = content.replaceFirst(oldString, newString);
      await file.writeAsString(newContent, flush: true);
      QuizzerLogger.logMessage('AI Tool Lib: File "$path" edited. Replaced first occurrence of "$oldString".');
    } else {
      QuizzerLogger.logWarning('AI Tool Lib: oldString "$oldString" not found in file "$path". File not modified.');
      return false; // oldString provided but not found
    }
  }
  return true; // Successfully written/modified
}

/// Lists files and directories within a given [directoryPath].
///
/// Corresponds to an agent's interpretation of an LLM requesting `list_files({})`.
/// If [directoryPath] is null or empty, it lists contents of the current working directory.
///
/// - [directoryPath]: The path to the directory. Defaults to current directory if null/empty.
///
/// Returns a list of names (not full paths) of files and directories as a [Future<List<String>>].
/// Throws a [FileSystemException] if the directory is not found or cannot be accessed.
Future<List<String>> listFilesTool({String? directoryPath}) async {
  final String pathToList = (directoryPath == null || directoryPath.isEmpty)
      ? Directory.current.path
      : directoryPath;
  QuizzerLogger.logMessage('AI Tool Lib: Executing listFilesTool for path: "$pathToList"');
  final dir = Directory(pathToList);
  if (!await dir.exists()) {
    final errorMsg = 'AI Tool Lib: Directory not found at path: $pathToList';
    QuizzerLogger.logError(errorMsg); // Re-evaluate
    throw FileSystemException(errorMsg, pathToList);
  }
  final List<String> entitiesNames = [];
  await for (final FileSystemEntity entity in dir.list()) {
    entitiesNames.add(entity.path.split(Platform.pathSeparator).last);
  }
  return entitiesNames;
}

/// Executes a system command.
///
/// This tool allows an agent to run commands, e.g., as implied by `node fizzbuzz.js` in the article.
/// Warning: Executing arbitrary commands suggested by an LLM can be a security risk.
/// Ensure proper sandboxing or validation if used in production.
///
/// - [executable]: The command or executable to run (e.g., "node", "python", "ls").
/// - [arguments]: A list of arguments for the command (e.g., ["fizzbuzz.js"], ["-l", "/tmp"]).
/// - [workingDirectory]: Optional directory in which to run the command. Defaults to current.
///
/// Returns a record `({int exitCode, String stdout, String stderr})` containing the
/// exit code, standard output, and standard error of the executed process.
Future<({int exitCode, String stdout, String stderr})> executeCommandTool({
  required String executable,
  List<String> arguments = const [],
  String? workingDirectory,
}) async {
  final String commandString = '$executable ${arguments.join(' ')}'.trim();
  final String effectiveDir = workingDirectory ?? Directory.current.path;
  QuizzerLogger.logMessage('AI Tool Lib: Executing command: "$commandString" in directory: "$effectiveDir"');
  // Using runInShell: true can be convenient but also has security implications
  // if the command string is directly from an untrusted source without sanitization.
  // For tools like `node script.js` it's generally fine.
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: effectiveDir,
    runInShell: Platform.isWindows, // runInShell often needed on Windows, less so on Linux/macOS for simple execs
  );

  QuizzerLogger.logMessage('AI Tool Lib: Command "$commandString" finished with exit code ${result.exitCode}.');
  if (result.stdout.toString().isNotEmpty) {
    QuizzerLogger.logMessage('AI Tool Lib: Command stdout:\\n${result.stdout}');
  }
  if (result.stderr.toString().isNotEmpty) {
    // Stderr is not always an "error" in the program sense, could be progress, warnings etc.
    QuizzerLogger.logMessage('AI Tool Lib: Command stderr:\\n${result.stderr}');
  }
  return (
    exitCode: result.exitCode,
    stdout: result.stdout.toString(),
    stderr: result.stderr.toString()
  );
}

// --- Web Search Tool ---

/// Internal placeholder for actually making the web search call.
/// This would involve using an HTTP client to call a search engine API.
Future<String> _performWebSearch(String query) async {
  QuizzerLogger.logMessage('AI Tool Lib: Attempting web search for query: "$query"');
  
  final Uri searchUri = Uri.parse('https://jsonplaceholder.typicode.com/todos/1?query=${Uri.encodeComponent(query)}'); 

  try {
    QuizzerLogger.logMessage('AI Tool Lib: Making network request to $searchUri');
    final response = await http.get(searchUri);

    if (response.statusCode == 200) {
      QuizzerLogger.logMessage('AI Tool Lib: Web search successful for query "$query". Status: ${response.statusCode}');
      return 'Example search result for "$query": ${response.body.substring(0, response.body.length > 150 ? 150 : response.body.length)}...';
    } else {
      final errorMsg = 'AI Tool Lib: Web search for "$query" failed with status: ${response.statusCode}, body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...';
      QuizzerLogger.logError(errorMsg);
      return errorMsg; // Return error message string instead of throwing
    }
  } catch (e, s) {
    // Catching network or other errors from http.get or subsequent processing
    final errorMsg = 'AI Tool Lib: Exception during _performWebSearch for query "$query": $e';
    QuizzerLogger.logError('$errorMsg\nStackTrace: $s');
    return errorMsg; // Return error message string instead of rethrowing
  }
}

/// Performs a web search for the given [query].
///
/// This tool uses an internal helper `_performWebSearch` which would typically use a
/// search engine API to fetch results. As this involves a network request, errors
/// are caught and rethrown as per guidelines.
///
/// - [query]: The search query string.
///
/// Returns a [Future<String>] containing the search results (e.g., a formatted
/// string of summaries and links).
/// Throws an exception if the web search fails (e.g., network error, API error).
Future<String> webSearchTool({required String query}) async {
  QuizzerLogger.logMessage('AI Tool Lib: Executing webSearchTool for query: "$query"');
  // The actual network call is encapsulated within _performWebSearch
  final String results = await _performWebSearch(query);
  QuizzerLogger.logMessage('AI Tool Lib: Web search for "$query" completed successfully.');
  return results;
}

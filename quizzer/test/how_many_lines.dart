import 'dart:io';
import 'dart:async';

// Function to count lines in all .dart files within a directory recursively
Future<int> countLinesInDirectory(String path) async {
  int totalLines = 0;
  final directory = Directory(path);

  if (!await directory.exists()) {
    print('Warning: Directory not found: $path');
    return 0;
  }

  final Stream<FileSystemEntity> entities = directory.list(
    recursive: true,
    followLinks: false, // Avoid counting linked files multiple times
  );

  await for (final FileSystemEntity entity in entities) {
    if (entity is File && entity.path.endsWith('.dart')) {
      try {
        final lines = await entity.readAsLines();
        totalLines += lines.length;
      } catch (e) {
        print('Warning: Could not read file ${entity.path}: $e');
      }
    }
  }
  return totalLines;
}

Future<void> main() async {
  print('Calculating total lines of code...');

  // Define paths relative to the project root (where the script is likely run from)
  final backendPath = 'lib/backend_systems';
  final uiPath = 'lib/UI_systems';
  final testPath = 'test';

  // Count lines in parallel
  final Future<int> backendLinesFuture = countLinesInDirectory(backendPath);
  final Future<int> uiLinesFuture = countLinesInDirectory(uiPath);
  final Future<int> testLinesFuture = countLinesInDirectory(testPath);

  // Wait for all counts to complete
  final backendLines = await backendLinesFuture;
  final uiLines = await uiLinesFuture;
  final testLines = await testLinesFuture;

  // Calculate total lines
  final totalLines = backendLines + uiLines + testLines;

  // Print the results
  print('\n--- Line Count Summary ---');
  print('Total_Backend_Systems: $backendLines');
  print('Total_UI_Systems:      $uiLines');
  print('Total_Test_Lines:      $testLines');
  print('--------------------------');
  print('Total_Lines:           $totalLines');
  print('--------------------------');
}

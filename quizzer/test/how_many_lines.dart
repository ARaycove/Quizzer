import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';

// Recursively count lines in all .dart files in a directory and its subdirectories
Future<int> countLinesInDirectory(String path) async {
  int totalLines = 0;
  final directory = Directory(path);

  if (!await directory.exists()) {
    QuizzerLogger.logWarning('Directory not found: $path');
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
        QuizzerLogger.logWarning('Could not read file ${entity.path}: $e');
      }
    }
  }
  return totalLines;
}

// Recursively build a tree of line counts for all subdirectories
Future<Map<String, dynamic>> buildDirectoryLineTree(String path) async {
  final directory = Directory(path);
  final Map<String, dynamic> result = {};
  int dirTotal = 0;

  if (!await directory.exists()) {
    return {'_lines': 0};
  }

  final List<FileSystemEntity> entities = await directory.list(followLinks: false).toList();
  // Count lines in .dart files directly in this directory
  for (final entity in entities) {
    if (entity is File && entity.path.endsWith('.dart')) {
      try {
        final lines = await entity.readAsLines();
        dirTotal += lines.length;
      } catch (e) {
        // Ignore file read errors
      }
    }
  }
  // Recurse into subdirectories
  for (final entity in entities) {
    if (entity is Directory) {
      final subdirName = entity.path.split(Platform.pathSeparator).last;
      final subTree = await buildDirectoryLineTree(entity.path);
      result[subdirName] = subTree;
      dirTotal += (subTree['_lines'] as int? ?? 0);
    }
  }
  result['_lines'] = dirTotal;
  return result;
}

// Pretty print the directory line tree with indentation, tree branches, and aligned columns
void logDirectoryLineTree(
  Map<String, dynamic> tree, {
  String prefix = '',
  bool isRoot = true,
  bool isLast = true,
  int dirNameWidth = 40,
}) {
  final entries = tree.entries
      .where((e) => e.key != '_lines')
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  for (int i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final subTree = entry.value as Map<String, dynamic>;
    final lines = subTree['_lines'] as int? ?? 0;
    final bool last = i == entries.length - 1;
    final branch = isRoot ? '' : (last ? '└── ' : '├── ');
    final nextPrefix = isRoot ? '' : (last ? '    ' : '│   ');
    // Directory name padded to fixed width
    final dirName = '${entry.key}/';
    final paddedDir = dirName.padRight(dirNameWidth);
    final lineStr = lines.toString().padLeft(6);
    QuizzerLogger.logMessage('$prefix$branch$paddedDir $lineStr');
    logDirectoryLineTree(
      subTree,
      prefix: prefix + nextPrefix,
      isRoot: false,
      isLast: last,
      dirNameWidth: dirNameWidth,
    );
  }
}

void main() {
  // Ensure logger is initialized first, setting level to FINE to see logValue messages
  QuizzerLogger.setupLogging(level: Level.FINE);
  
  group('Code Line Count Tests', () {
    test('should count lines in all dart files and provide breakdown', () async {
      QuizzerLogger.logMessage('Calculating total lines of code...');

      // Define paths relative to the project root (where the script is likely run from)
      const backendPath = 'lib/backend_systems';
      const uiPath = 'lib/UI_systems';
      const testPath = 'test';

      // Count lines in parallel
      final Future<int> backendLinesFuture = countLinesInDirectory(backendPath);
      final Future<int> uiLinesFuture = countLinesInDirectory(uiPath);
      final Future<int> testLinesFuture = countLinesInDirectory(testPath);
      final Future<Map<String, dynamic>> backendTreeFuture = buildDirectoryLineTree(backendPath);
      final Future<Map<String, dynamic>> uiTreeFuture = buildDirectoryLineTree(uiPath);

      // Wait for all counts to complete
      final backendLines = await backendLinesFuture;
      final uiLines = await uiLinesFuture;
      final testLines = await testLinesFuture;
      final backendTree = await backendTreeFuture;
      final uiTree = await uiTreeFuture;

      // Calculate total lines
      final totalLines = backendLines + uiLines + testLines;

      // Log the results
      QuizzerLogger.logMessage('\n--- Line Count Summary ---');
      QuizzerLogger.logMessage('Total_Backend_Systems: $backendLines');
      QuizzerLogger.logMessage('Total_UI_Systems:      $uiLines');
      QuizzerLogger.logMessage('Total_Test_Lines:      $testLines');
      QuizzerLogger.logMessage('--------------------------');
      QuizzerLogger.logMessage('Total_Lines:           $totalLines');
      QuizzerLogger.logMessage('--------------------------');

      QuizzerLogger.logMessage('\n--- Backend Systems Breakdown (recursive, alphabetical) ---');
      logDirectoryLineTree(backendTree);
      QuizzerLogger.logMessage('\n--- UI Systems Breakdown (recursive, alphabetical) ---');
      logDirectoryLineTree(uiTree);

      // Assert that we have some code (basic validation)
      expect(totalLines, greaterThan(0), reason: 'Should have at least some lines of code');
      expect(backendLines, greaterThan(0), reason: 'Should have backend code');
      expect(uiLines, greaterThan(0), reason: 'Should have UI code');
    });
  });
}

# StatField Implementation Specification

## Overview
The system uses a `StatField` abstraction pattern for modular, self-contained statistics calculation in a quiz application. Each statistic is a singleton class that follows a consistent pattern.

## Core Principles

### 1. **Singleton Pattern**
- Every StatField MUST be implemented as a singleton
- Use the exact pattern:
  ```dart
  static final ClassName _instance = ClassName._internal();
  factory ClassName() => _instance;
  ClassName._internal();
  ```

### 2. **Required Getters**
Every StatField MUST implement these getters:
- `name`: String - The database column name (snake_case)
- `type`: String - SQLite type ("INTEGER", "REAL", "TEXT")
- `defaultValue`: dynamic - Default when no data exists
- `currentValue`: dynamic getter/setter - Cached value with backing field
- `description`: String - Clear description of the stat
- `isIncremental`: bool - Whether stat increments (usually false for calculated stats)

### 3. **Required Methods**
- `recalculateStat()`: Primary calculation logic
- `calculateCarryForwardValue()`: Logic for filling missing days

## Implementation Rules

### 1. **Dependency Order**
- Stats are calculated in the order defined in `UserDailyStatsTable._statClasses`
- Dependencies must be listed BEFORE dependent stats
- ALWAYS access other stats via their singleton: `OtherStat().currentValue`
- DO NOT query for data already available in other stats
- Stats will be up-to-date when accessed if dependencies are ordered correctly

### 2. **recalculateStat() Method**
```dart
Future<Type> recalculateStat({
  Transaction? txn, 
  bool? isCorrect, 
  double? reactionTime, 
  String? questionId, 
  String? questionType
})
```
- Use `isCorrect != null` to determine if updating from a new answer
- Use `txn!` for database queries (transaction is guaranteed)
- Update `currentValue` before returning
- Return the calculated value
- Wrap in try-catch with `QuizzerLogger.logError()`

### 3. **calculateCarryForwardValue() Method**
```dart
Future<Type> calculateCarryForwardValue({
  Transaction? txn,
  Map<String, dynamic>? previousRecord,
  Map<String, dynamic>? currentIncompleteRecord
})
```
- For most stats: return `previousRecord[name] ?? defaultValue`
- Only implement complex logic if stat changes without user interaction
- Update `currentValue` before returning

### 4. **Database Queries**
- Use `SessionManager().userId` for user-specific queries
- NEVER duplicate calculation logic that exists in other stats
- Use existing `avg_reaction_time` in `user_question_answer_pairs` for reaction stats
- For distribution stats (like revision streaks), use `table_helper.encodeValueForDB()`

### 5. **Imports**
Always include:
```dart
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common/sqlite_api.dart';
```
- For JSON encoding: `import 'package:quizzer/backend_systems/00_database_manager/tables/table_helper.dart' as table_helper;`

## Common Patterns

### 1. **Accuracy Stat Pattern**
```dart
double accuracy = defaultValue;
if (attempts > 0) {
  accuracy = correct / attempts;
}
```

### 2. **Streak Stat Pattern**
```dart
if (isCorrect != null) {
  if (isCorrect) {
    currentStreak += 1;
    // Reset opposite streak to 0
  } else {
    currentStreak = 0;
  }
}
```

### 3. **Carry-Forward Pattern**
```dart
if (previousRecord == null) return defaultValue;
return previousRecord[name] ?? defaultValue;
```

### 4. **Database Query Pattern**
```dart
final results = await txn!.rawQuery(query, [SessionManager().userId]);
if (results.isEmpty) return defaultValue;
return results.first['field'] as Type;
```

## Anti-Patterns (NEVER DO THESE)

### ❌ **WRONG:** Duplicating other stats' logic
```dart
// DON'T: Recalculate avg_daily_questions_learned from scratch
// DO: Use AvgDailyQuestionsLearned().currentValue
```

### ❌ **WRONG:** Creating new encoding functions
```dart
// DON'T: Write your own encodeValueForDB()
// DO: Use table_helper.encodeValueForDB()
```

### ❌ **WRONG:** Making unnecessary database queries
```dart
// DON'T: Query for total_attempts when TotalAttempts().currentValue exists
// DO: Use TotalAttempts().currentValue
```

### ❌ **WRONG:** Overcomplicating carry-forward
```dart
// DON'T: Complex logic unless absolutely necessary
// DO: return previousRecord[name] ?? defaultValue
```

## Example Template

```dart
import 'package:quizzer/backend_systems/00_database_manager/tables/user_profile/stat_handling/stat_field.dart';
import 'package:quizzer/backend_systems/session_manager/session_manager.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'package:sqflite_common/sqlite_api.dart';

class StatName extends StatField {
  static final StatName _instance = StatName._internal();
  factory StatName() => _instance;
  StatName._internal();

  @override String get name => "stat_name";
  @override String get type => "TYPE";
  @override get defaultValue => DEFAULT_VALUE;
  
  _cachedValue = DEFAULT_VALUE;
  @override get currentValue => _cachedValue;
  set currentValue(value) { _cachedValue = value; }
  
  @override String get description => "Description";
  @override bool get isIncremental => false;

  @override
  Future<Type> recalculateStat({Transaction? txn, bool? isCorrect, double? reactionTime, String? questionId, String? questionType}) async {
    try {
      // Calculation logic here
      // Use OtherStat().currentValue for dependencies
      final result = ...;
      currentValue = result;
      return result;
    } catch (e) {
      QuizzerLogger.logError('Failed to recalculate $name: $e');
      rethrow;
    }
  }

  @override
  Future<Type> calculateCarryForwardValue({
    Transaction? txn, 
    Map<String, dynamic>? previousRecord, 
    Map<String, dynamic>? currentIncompleteRecord
  }) async {
    try {
      if (previousRecord == null) {
        currentValue = defaultValue;
        return currentValue;
      }
      final previousValue = (previousRecord[name] as Type?) ?? defaultValue;
      currentValue = previousValue;
      return currentValue;
    } catch (e) {
      QuizzerLogger.logError('Failed to calculate carry-forward for $name: $e');
      rethrow;
    }
  }
}
```

## Verification Checklist
Before completing any StatField implementation, verify:
- [ ] Singleton pattern correct
- [ ] All getters implemented
- [ ] Uses dependencies via singleton (not queries)
- [ ] Simple carry-forward logic (unless exceptional)
- [ ] Proper error logging
- [ ] Updates currentValue before returning
- [ ] No duplicate encoding/helper functions
- [ ] Imports are minimal and correct

This specification ensures consistency across all StatField implementations. Follow exactly - deviations will break the system.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quizzer/database/tables/user_profile_table.dart';

class SessionManager {
  // Singleton instance
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  // Secure storage instance
  final _storage = const FlutterSecureStorage();

  // Session state variables
  String? _userId;
  String? _email;
  String? _currentQuestionId;
  bool _hasBeenFlipped = false;
  bool _isQuestionSideActive = true;
  bool _buttonsEnabled = true;
  DateTime? _sessionStartTime;
  DateTime? _questionPresentedTime;
  DateTime? _questionAnsweredTime;
  Duration? _elapsedTime;

  // Getters
  String? get userId => _userId;
  String? get email => _email;
  String? get currentQuestionId => _currentQuestionId;
  bool get hasBeenFlipped => _hasBeenFlipped;
  bool get isQuestionSideActive => _isQuestionSideActive;
  bool get buttonsEnabled => _buttonsEnabled;
  DateTime? get sessionStartTime => _sessionStartTime;
  DateTime? get questionPresentedTime => _questionPresentedTime;
  DateTime? get questionAnsweredTime => _questionAnsweredTime;
  Duration? get elapsedTime => _elapsedTime;

  // Setters
  set buttonsEnabled(bool value) => _buttonsEnabled = value;

  // Initialize session with email
  Future<void> initializeSession(String email) async {
    _email = email;
    _userId = await getUserIdByEmail(email);
    _sessionStartTime = DateTime.now();
    resetQuestionState();
  }

  // Update current question
  void setCurrentQuestionId(String questionId) {
    _currentQuestionId = questionId;
    resetQuestionState();
  }

  // Toggle card side
  void toggleCardSide() {
    _isQuestionSideActive = !_isQuestionSideActive;
  }

  // Set has been flipped
  void setHasBeenFlipped(bool value) {
    _hasBeenFlipped = value;
  }

  // Set question presented time
  void setQuestionPresentedTime() {
    _questionPresentedTime = DateTime.now();
  }

  // Set question answered time
  void setQuestionAnsweredTime() {
    _questionAnsweredTime = DateTime.now();
  }

  // Get session duration in seconds
  double? getSessionDuration() {
    if (_sessionStartTime == null) return null;
    return DateTime.now().difference(_sessionStartTime!).inMilliseconds / 1000.0;
  }

  // Get elapsed time in seconds
  double? getElapsedTime() {
    if (_questionPresentedTime == null || _questionAnsweredTime == null) return null;
    return _questionAnsweredTime!.difference(_questionPresentedTime!).inMilliseconds / 1000.0;
  }

  // Reset question-specific state
  void resetQuestionState() {
    _hasBeenFlipped = false;
    _isQuestionSideActive = true;
    _buttonsEnabled = false;
    _questionPresentedTime = null;
    _questionAnsweredTime = null;
    _elapsedTime = null;
  }

  // Clear session
  Future<void> clearSession() async {
    _userId = null;
    _email = null;
    _currentQuestionId = null;
    resetQuestionState();
    _sessionStartTime = null;
    await _storage.deleteAll();
  }
}

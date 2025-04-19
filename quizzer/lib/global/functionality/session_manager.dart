import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quizzer/global/functionality/session_isolates.dart';

class SessionManager {
  // Singleton instance
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  // Secure storage instance
  final _storage = const FlutterSecureStorage();

  // Session state variables
  String? userId;
  String? email;
  String? currentQuestionId;
  bool hasBeenFlipped = false;
  bool isQuestionSideActive = true;
  bool buttonsEnabled = true;
  DateTime? sessionStartTime;
  DateTime? questionPresentedTime;
  DateTime? questionAnsweredTime;
  Duration? elapsedTime;
  
  // Page history tracking
  final List<String> _pageHistory = [];
  static const int _maxHistoryLength = 12;

  // Add page to history
  void addPageToHistory(String routeName) {
    if (_pageHistory.isNotEmpty && _pageHistory.last == routeName) {
      return; // Don't add duplicate consecutive pages
    }
    _pageHistory.add(routeName);
    if (_pageHistory.length > _maxHistoryLength) {
      _pageHistory.removeAt(0);
    }
  }

  // Get previous page
  String? getPreviousPage() {
    if (_pageHistory.length < 2) return null;
    return _pageHistory[_pageHistory.length - 2];
  }

  // Clear page history
  void clearPageHistory() {
    _pageHistory.clear();
  }

  // Question and answer data
  List<Map<String, dynamic>> questionElements = [];
  List<Map<String, dynamic>> answerElements = [];

  // Initialize session with email
  Future<void> initializeSession(String email) async {
    final userId = await handleSessionInitialization({
      'email': email,
    });
    
    if (userId == null) {
      throw Exception('Failed to initialize session: No user found');
    }
    
    this.email = email;
    this.userId = userId;
    sessionStartTime = DateTime.now();
    resetQuestionState();
  }

  // Update current question
  void setCurrentQuestionId(String questionId) {
    currentQuestionId = questionId;
    resetQuestionState();
  }

  // Set question and answer elements
  void setQuestionAndAnswerElements(
      List<Map<String, dynamic>> questionElements,
      List<Map<String, dynamic>> answerElements) {
    this.questionElements = questionElements;
    this.answerElements = answerElements;
  }

  // Toggle card side
  void toggleCardSide() {
    isQuestionSideActive = !isQuestionSideActive;
  }

  // Set has been flipped
  void setHasBeenFlipped(bool value) {
    hasBeenFlipped = value;
  }

  // Set question presented time
  void setQuestionPresentedTime() {
    questionPresentedTime = DateTime.now();
  }

  // Set question answered time
  void setQuestionAnsweredTime() {
    questionAnsweredTime = DateTime.now();
  }

  // Get session duration in seconds
  double? getSessionDuration() {
    if (sessionStartTime == null) return null;
    return DateTime.now().difference(sessionStartTime!).inMilliseconds / 1000.0;
  }

  // Get elapsed time in seconds
  double? getElapsedTime() {
    if (questionPresentedTime == null || questionAnsweredTime == null) return null;
    return questionAnsweredTime!.difference(questionPresentedTime!).inMilliseconds / 1000.0;
  }

  // Reset question-specific state
  void resetQuestionState() {
    hasBeenFlipped = false;
    isQuestionSideActive = true;
    buttonsEnabled = false;
    questionPresentedTime = null;
    questionAnsweredTime = null;
    elapsedTime = null;
    questionElements.clear();
    answerElements.clear();
  }

  // Clear session
  Future<void> clearSession() async {
    userId = null;
    email = null;
    currentQuestionId = null;
    resetQuestionState();
    sessionStartTime = null;
    await _storage.deleteAll();
  }
}

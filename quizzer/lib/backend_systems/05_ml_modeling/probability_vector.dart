Future<Map<String, dynamic>> get_prediction_vector(String question_id) async {
  // User Profile Information
  int age                          = 0;  // FIXME
  var highestLevelOfEducation      = ""; // FIXME
  var undergradMajor               = ""; // FIXME
  var minor                        = []; // FIXME
  var gradMajor                    = []; // FIXME
  var countryOfOrigin              = ""; // FIXME
  var currentCountryOfResidence    = ""; // FIXME
  var currentState                 = ""; // FIXME
  var currentCity                  = ""; // FIXME
  var religion                     = ""; // FIXME
  var politicalAffiliation         = ""; // FIXME
  var nativeLanguage               = ""; // FIXME
  var otherLanguageProficiencies   = []; // FIXME
  var currentOccupationIndustry    = ""; // FIXME
  var householdIncome              = 0;  // FIXME
  var hoursWorkedPerWeek           = 0;  // FIXME
  var yearsWorkExperience          = 0;  // FIXME
  var totalJobChanges              = 0;  // FIXME
  var maritalStatus                = ""; // FIXME
  var numberOfChildren             = 0;  // FIXME
  var urbanVsRural                 = ""; // FIXME
  var militaryService              = 0;  // FIXME
  var learningDisabilities         = ""; // FIXME
  var numLanguagesSpoken           = 0;  // FIXME
  var yearsSinceGraduation         = 0;  // FIXME
  var commuteTimeMinutes           = 0;  // FIXME
  var familyEducationalBackground  = ""; // FIXME
  var disabilityStatus             = ""; // FIXME
  var housingSituation             = ""; // FIXME
  var birthOrder                   = ""; // FIXME
  
  // User Question Relation Data
  var transformedQuestionVector    = []; // FIXME
  var moduleName                   = ""; // FIXME
  var questionType                 = ""; // FIXME
  var numberMcqOptions             = 0;  // FIXME
  var numberSortOrderOptions       = 0;  // FIXME
  var numberSelectAllOptions       = 0;  // FIXME
  var numberBlankOptions           = 0;  // FIXME
  var avgLengthOfBlanks            = 0;  // FIXME
  var isMathBlank                  = 0;  // FIXME
  var firstAttempt                 = 0;  // FIXME
  var totalAttempts                = 0;  // FIXME
  var totalCorrectAttempts         = 0;  // FIXME
  var totalIncorrectAttempts       = 0;  // FIXME
  var questionAccuracyRate         = 0;  // FIXME
  var questionInaccuracyRate       = 0;  // FIXME
  var revisionStreak               = 0;  // FIXME
  var lastRevisedUtc               = ""; // FIXME
  var daysSinceLastRevision        = 0;  // FIXME
  var currentTimeUtc               = ""; // FIXME
  var daysSinceFirstIntroduced     = 0;  // FIXME
  var attemptDayRatio              = 0;  // FIXME
  var averageHesitation            = 0;  // FIXME
  var averageReactionTime          = 0;  // FIXME
  
  // Module Performance Data
  var moduleNumMcq                 = 0;  // FIXME
  var moduleNumFitb                = 0;  // FIXME
  var moduleNumSata                = 0;  // FIXME
  var moduleNumTf                  = 0;  // FIXME
  var moduleNumSo                  = 0;  // FIXME
  var moduleNumTotal               = 0;  // FIXME
  var moduleTotalSeen              = 0;  // FIXME
  var modulePercentileSeen         = 0;  // FIXME
  var moduleAvgAttemptsPerQuestion = 0;  // FIXME
  var moduleTotalAttempts          = 0;  // FIXME
  var moduleTotalCorrect           = 0;  // FIXME
  var moduleTotalIncorrect         = 0;  // FIXME
  var moduleOverallAccuracy        = 0;  // FIXME
  var moduleAvgReactionTime        = 0;  // FIXME
  var moduleDaysTakenToMaster      = 0;  // FIXME
  var moduleDaysSinceLastSeen      = 0;  // FIXME
  
  return {
    'age': age,
    'highestLevelOfEducation': highestLevelOfEducation,
    'undergradMajor': undergradMajor,
    'minor': minor,
    'gradMajor': gradMajor,
    'countryOfOrigin': countryOfOrigin,
    'currentCountryOfResidence': currentCountryOfResidence,
    'currentState': currentState,
    'currentCity': currentCity,
    'religion': religion,
    'politicalAffiliation': politicalAffiliation,
    'nativeLanguage': nativeLanguage,
    'otherLanguageProficiencies': otherLanguageProficiencies,
    'currentOccupationIndustry': currentOccupationIndustry,
    'householdIncome': householdIncome,
    'hoursWorkedPerWeek': hoursWorkedPerWeek,
    'yearsWorkExperience': yearsWorkExperience,
    'totalJobChanges': totalJobChanges,
    'maritalStatus': maritalStatus,
    'numberOfChildren': numberOfChildren,
    'urbanVsRural': urbanVsRural,
    'militaryService': militaryService,
    'learningDisabilities': learningDisabilities,
    'numLanguagesSpoken': numLanguagesSpoken,
    'yearsSinceGraduation': yearsSinceGraduation,
    'commuteTimeMinutes': commuteTimeMinutes,
    'familyEducationalBackground': familyEducationalBackground,
    'disabilityStatus': disabilityStatus,
    'housingSituation': housingSituation,
    'birthOrder': birthOrder,
    'transformedQuestionVector': transformedQuestionVector,
    'moduleName': moduleName,
    'questionType': questionType,
    'numberMcqOptions': numberMcqOptions,
    'numberSortOrderOptions': numberSortOrderOptions,
    'numberSelectAllOptions': numberSelectAllOptions,
    'numberBlankOptions': numberBlankOptions,
    'avgLengthOfBlanks': avgLengthOfBlanks,
    'isMathBlank': isMathBlank,
    'firstAttempt': firstAttempt,
    'totalAttempts': totalAttempts,
    'totalCorrectAttempts': totalCorrectAttempts,
    'totalIncorrectAttempts': totalIncorrectAttempts,
    'questionAccuracyRate': questionAccuracyRate,
    'questionInaccuracyRate': questionInaccuracyRate,
    'revisionStreak': revisionStreak,
    'lastRevisedUtc': lastRevisedUtc,
    'daysSinceLastRevision': daysSinceLastRevision,
    'currentTimeUtc': currentTimeUtc,
    'daysSinceFirstIntroduced': daysSinceFirstIntroduced,
    'attemptDayRatio': attemptDayRatio,
    'averageHesitation': averageHesitation,
    'averageReactionTime': averageReactionTime,
    'moduleNumMcq': moduleNumMcq,
    'moduleNumFitb': moduleNumFitb,
    'moduleNumSata': moduleNumSata,
    'moduleNumTf': moduleNumTf,
    'moduleNumSo': moduleNumSo,
    'moduleNumTotal': moduleNumTotal,
    'moduleTotalSeen': moduleTotalSeen,
    'modulePercentileSeen': modulePercentileSeen,
    'moduleAvgAttemptsPerQuestion': moduleAvgAttemptsPerQuestion,
    'moduleTotalAttempts': moduleTotalAttempts,
    'moduleTotalCorrect': moduleTotalCorrect,
    'moduleTotalIncorrect': moduleTotalIncorrect,
    'moduleOverallAccuracy': moduleOverallAccuracy,
    'moduleAvgReactionTime': moduleAvgReactionTime,
    'moduleDaysTakenToMaster': moduleDaysTakenToMaster,
    'moduleDaysSinceLastSeen': moduleDaysSinceLastSeen,
  };
}
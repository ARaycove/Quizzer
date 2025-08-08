/// List of exam/certification strings that should be displayed in full uppercase
final List<String> _examCertificationStrings = [
  'mcat',
  'clep',
  // Add more exam/certification strings here as needed
];

/// Converts a normalized module name to Title Case for display
/// Handles special cases like roman numerals (i, ii, iii -> I, II, III)
/// and exam/certification strings (mcat -> MCAT, clep -> CLEP)
String formatModuleNameForDisplay(String normalizedModuleName) {
  if (normalizedModuleName.isEmpty) {
    return normalizedModuleName;
  }

  // Split the module name into words
  final List<String> words = normalizedModuleName.split(' ');
  final List<String> formattedWords = [];

  for (int i = 0; i < words.length; i++) {
    String word = words[i].trim();
    
    if (word.isEmpty) continue;

    // Special handling for exam/certification strings
    if (_examCertificationStrings.contains(word.toLowerCase())) {
      formattedWords.add(word.toUpperCase());
    }
    // Special handling for roman numerals
    else if (_isRomanNumeral(word)) {
      formattedWords.add(word.toUpperCase());
    } else {
      // Regular title case conversion
      if (word.length == 1) {
        formattedWords.add(word.toUpperCase());
      } else {
        formattedWords.add(word[0].toUpperCase() + word.substring(1).toLowerCase());
      }
    }
  }

  return formattedWords.join(' ');
}

/// Checks if a word is a roman numeral (i, ii, iii, iv, v, vi, vii, viii, ix, x, etc.)
bool _isRomanNumeral(String word) {
  final String lowerWord = word.toLowerCase();
  
  // Common roman numeral patterns
  final List<String> romanNumerals = [
    'i', 'ii', 'iii', 'iv', 'v', 'vi', 'vii', 'viii', 'ix', 'x',
    'xi', 'xii', 'xiii', 'xiv', 'xv', 'xvi', 'xvii', 'xviii', 'xix', 'xx',
    'xxi', 'xxii', 'xxiii', 'xxiv', 'xxv', 'xxvi', 'xxvii', 'xxviii', 'xxix', 'xxx'
  ];
  
  return romanNumerals.contains(lowerWord);
}

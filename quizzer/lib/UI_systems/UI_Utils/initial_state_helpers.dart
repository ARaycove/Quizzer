/// Converts various types to boolean for settings widgets.
/// Handles int (1/0), double (1.0/0.0), String ("1"/"0"), and other types.
/// Returns false for null, 0, 0.0, "0", and any other falsy values.
bool convertToBoolean(dynamic value) {
  if (value == null) return false;
  
  if (value is bool) return value;
  if (value is int) return value == 1;
  if (value is double) return value == 1.0;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed == "1" || trimmed.toLowerCase() == "true";
  }
  
  return false;
}

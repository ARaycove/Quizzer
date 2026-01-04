# Reset Password Feature Specification

**Feature**: Supabase Auth Reset Password  
**Status**: Partially Implemented (Backend functional, Frontend disabled)  
**Date Created**: January 4, 2026  
**Objective**: Enable users to reset their passwords when they forget them

---

## 1. Current Implementation Status

### Backend: ✅ IMPLEMENTED
- `reset_password.dart` - Handles password recovery logic
- Function: `handlePasswordRecovery()`
- Uses Supabase's `resetPasswordForEmail()` API

### Frontend: ⚠️ DISABLED (NEEDS ENABLEMENT)
- `reset_password_page.dart` - UI fully coded but **ALL COMMENTED OUT**
- Navigation hook exists in `login_page.dart` but route is disabled in `main.dart`
- Button in login page references `resetPassword()` but link is commented

### Routing: ❌ NOT ACTIVE
- Route `/resetPassword` is commented out in `main.dart`
- Import statement commented out in `main.dart`

---

## 2. Current User Flow (What EXISTS in Code)

### Step 1: User enters email
- User navigates from login page to reset password page
- Enters their registered email address
- Clicks "Send OTP"

### Step 2: OTP sent via email
- Backend calls `supabase.auth.resetPasswordForEmail(email)`
- Supabase sends recovery email with password reset link/OTP
- A 60-second cooldown timer prevents spam resend

### Step 3: User verifies OTP
- User enters OTP from email
- Frontend calls `supabase.auth.verifyOTP()` with recovery type
- On success, moves to password reset step

### Step 4: Set new password
- User enters new password twice (validation: min 6 chars, must match)
- Frontend calls `supabase.auth.updateUser()` with new password
- User is redirected back to login page with success message

---

## 3. Desired Behavior

### On Login Page
- Add visible "Forgot Password?" button/link (currently commented out)
- Button should be easily discoverable below password field
- On click: Navigate to reset password flow

### Reset Password Page Flow
1. **Email Entry Screen**
   - Text field for email input
   - "Send OTP" button
   - Loading indicator during API call
   - Error handling for invalid emails or non-existent accounts

2. **OTP Entry Screen**
   - Text field for 6-digit OTP
   - "Verify OTP" button
   - "Resend OTP" button with 60-second cooldown
   - Display remaining time on resend button

3. **New Password Screen**
   - Two password fields (new password + confirmation)
   - Password strength requirements displayed
   - "Update Password" button
   - Clear error messages for mismatches or weak passwords

4. **Success State**
   - Confirmation message
   - Auto-redirect to login after 2 seconds
   - Allow manual "Back to Login" button

### Error Handling
- Non-existent email accounts: "Email not found" message
- Invalid OTP: "Invalid or expired OTP, request new one"
- Password mismatch: "Passwords do not match"
- Weak password: "Password must be at least 6 characters"
- Network errors: Graceful retry mechanism
- Expired OTP: Allow user to request new OTP

### Accessibility
- Loading states clearly indicated with spinners/progress text
- Error messages in red with clear language
- Button states properly disabled during loading
- Form validation before submission

---

## 4. Technical Implementation Details

### Backend Functions

#### `handlePasswordRecovery()` - Location: `/backend_systems/01_account_creation_and_management/reset_password.dart`
```dart
Future<Map<String, dynamic>> handlePasswordRecovery(
    Map<String, dynamic> message, 
    SupabaseClient supabase
) async
```
- **Input**: Email address
- **Output**: `{ success: bool, message: String }`
- **Current Issue**: ⚠️ Returns empty `{}` on success, should return `{ 'success': true }`
- **Status**: Partially working, needs fix

#### `UserAuth.attemptSupabaseLogin()` - Location: `/backend_systems/02_login_authentication/user_auth.dart`
- Handles standard login (relevant for context)
- Returns user data and session on success

### Frontend Components

#### Reset Password Page - Location: `/UI_systems/11_reset_password_page/reset_password_page.dart`
- **Current State**: Fully implemented but commented out AND has critical bugs
- **Critical Issues**:
  1. ❌ `late SupabaseClient supabase` is declared but NEVER INITIALIZED
  2. ❌ Uses direct SupabaseClient instead of `SessionManager().supabase`
  3. ❌ Will crash with "Uninitialized Late Variable" on first use
- **Key Methods**:
  - `_sendOtp()` - Initiates password recovery (will crash here)
  - `_verifyOtp()` - Validates OTP
  - `_submitNewPassword()` - Updates password in Supabase
- **Must Fix Before Activation**: Initialize supabase client properly

#### Login Page - Location: `/UI_systems/00_login_page/login_page.dart`
- **Method**: `resetPassword()` - Exists but button commented out
- Handles navigation to reset password flow
- Shows success message after reset

### Routing

#### Main App Routes - Location: `/main.dart`
- **Current**: Route commented out at line 120
- **Need to Enable**: Uncomment import and route registration

---

## 5. Supabase API Dependencies

### Used Endpoints
1. **Reset Password for Email**
   ```dart
   await supabase.auth.resetPasswordForEmail(email)
   ```
   - Sends recovery email with link/OTP

2. **Verify OTP**
   ```dart
   await supabase.auth.verifyOTP(
     email: email,
     token: otp,
     type: OtpType.recovery
   )
   ```
   - Verifies OTP from recovery email

3. **Update User Password**
   ```dart
   await supabase.auth.updateUser(
     UserAttributes(password: newPass)
   )
   ```
   - Updates password in Supabase

### Email Configuration
- Supabase sends recovery emails automatically
- Verify that email templates are configured in Supabase dashboard
- Test email delivery in development environment

---

## 6. Database/Storage Impact

### Users Table
- **No changes needed** - Password stored by Supabase auth system
- User roles/permissions remain unchanged
- Session data updated on successful reset

### Audit Trail (If Applicable)
- Consider logging password reset attempts for security
- Current logging uses `QuizzerLogger` system

---

## 7. UI/UX Considerations

### Theme Integration
- Uses `AppTheme` for consistent styling
- Color scheme: `colorScheme.onPrimary` for text inputs
- Standard button styling for consistency

### Loading States
- Progress messages streamed via `SessionManager().loginProgressStream`
- Loading indicator (spinner) during API calls
- Button disabled state during loading

### Error Messages
- SnackBar notifications for errors
- Inline validation feedback
- Clear, user-friendly language

---

## 8. Testing Checklist

- [ ] Navigate "Forgot Password" from login page
- [ ] Submit email (valid, invalid, non-existent accounts)
- [ ] Receive OTP in email
- [ ] Verify OTP successfully
- [ ] Enter new password with validation
- [ ] Confirm password mismatch error
- [ ] Confirm password too short error
- [ ] Successfully update password
- [ ] Log in with new password
- [ ] Resend OTP within cooldown (should fail)
- [ ] Resend OTP after cooldown expires
- [ ] Handle network errors gracefully
- [ ] Test on Linux, Android, iOS
- [ ] Verify back button navigation

---

## 9. Known Issues & Gaps

### Critical (Must Fix Before Activation)

1. ❌ **Backend Function Missing Return Value**
   - `handlePasswordRecovery()` returns empty map `{}` on success
   - Frontend expects `{ success: true }` response
   - **FIX**: Add `results = { 'success': true }` before return in reset_password.dart line ~28

2. ❌ **ResetPasswordPage Not Receiving Supabase Client**
   - `reset_password_page.dart` declares `late SupabaseClient supabase` but never initializes it
   - Will crash with "Uninitialized Late Variable" error when user tries to send OTP
   - **FIX**: Pass supabase from SessionManager in initState or constructor

3. ❌ **ResetPasswordPage Doesn't Use SessionManager**
   - All other pages in system use `SessionManager()` to access supabase
   - Reset password page uses `late SupabaseClient supabase` (never initialized)
   - **FIX**: Use `SessionManager().supabase` instead

### High Priority

4. **Email Configuration**: Verify Supabase email templates are set up correctly
5. **OTP Timeout**: No explicit timeout handling shown - verify Supabase's default OTP expiry (usually 15 mins)

### Medium Priority

6. **Rate Limiting**: No rate limiting visible - may want to add to prevent abuse
7. **Password Requirements**: Currently only 6+ chars, no complexity rules - may want stricter requirements
8. **Navigation Return Value**: `resetPassword()` in login_page expects boolean return, current implementation doesn't guarantee this

---

## 10. Dependencies & Package Versions

- **supabase**: ^2.0.0+ (for Flutter)
- **flutter**: Stability stable channel
- **hive**: For local storage (used in SessionManager)
- **logging**: For error logging

---

## 11. Future Enhancements

- [ ] Add password strength indicator
- [ ] Support biometric authentication after password reset
- [ ] Add two-factor authentication option
- [ ] Implement rate limiting on password reset requests
- [ ] Add "Last password changed" to user profile
- [ ] Email confirmation for password change notifications
- [ ] Allow password reset without OTP (magic link only)
- [ ] Dark mode for reset password page

---

## 12. Activation Steps (To Enable Feature)

1. Uncomment import in `main.dart` line 19
2. Uncomment route in `main.dart` line 120
3. Uncomment "Reset Password" button in `login_page.dart`
4. Uncomment all code in `reset_password_page.dart`
5. Test thoroughly on all platforms
6. Deploy to production

---

## 13. Questions & Clarifications Needed

- Should password reset require email verification first?
- What's the OTP expiry time in Supabase configuration?
- Should we implement password reset via magic link instead of OTP?
- What are the password complexity requirements?
- Should failed reset attempts be logged for security audit?

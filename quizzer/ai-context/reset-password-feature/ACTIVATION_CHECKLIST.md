# Activation Checklist for Reset Password Feature

## Pre-Activation Tasks

- [ ] Review `RESET_PASSWORD_FEATURE_SPEC.md` completely
- [ ] Understand the 3-step OTP flow (Email → OTP → New Password)
- [ ] Verify Supabase project has email configured
- [ ] Check that Supabase email templates are set up

## Code Changes Required

### 1. main.dart
**File**: `/quizzer/lib/main.dart`

**Line 19**: Uncomment import
```dart
import 'UI_systems/11_reset_password_page/reset_password_page.dart';
```

**Line 120**: Uncomment route
```dart
'/resetPassword':   (context) => const ResetPasswordPage(),
```

### 2. login_page.dart
**File**: `/quizzer/lib/UI_systems/00_login_page/login_page.dart`

**Around line 237**: Uncomment "Reset Password" button
Look for commented TextButton with "Reset Password" text and uncomment it.

### 3. reset_password_page.dart
**File**: `/quizzer/lib/UI_systems/11_reset_password_page/reset_password_page.dart`

**Action**: Uncomment the entire file (all commented code)

## Post-Activation Testing

### Manual Testing

- [ ] Navigate to login page
- [ ] Click "Forgot Password?" link
- [ ] Enter valid registered email → OTP received in email
- [ ] Enter OTP code → Successfully verified
- [ ] Enter new password (6+ chars) → Successfully updated
- [ ] Log in with new password → Success

### Error Cases

- [ ] Enter non-existent email → Appropriate error message
- [ ] Enter invalid OTP → Error and ability to resend
- [ ] Enter mismatched passwords → Validation error
- [ ] Enter password < 6 chars → Validation error
- [ ] Test resend cooldown → Disabled for 60 seconds

### Platform Testing

- [ ] Test on Linux desktop
- [ ] Test on Android (if applicable)
- [ ] Test on iOS (if applicable)

### Edge Cases

- [ ] Network error during OTP send → Graceful handling
- [ ] Network error during OTP verification → Graceful handling
- [ ] Network error during password update → Graceful handling
- [ ] Go back during flow → Clean state
- [ ] Session timeout → Redirect to login

## Deployment Steps

1. Create feature branch (already done: `nj-ui-ux-dev-002`)
2. Make code changes (uncomment as per checklist above)
3. Run `flutter clean && flutter pub get`
4. Test thoroughly on all platforms
5. Commit changes
6. Push to remote
7. Create pull request for review
8. Merge after review
9. Deploy to production

## Post-Deployment

- [ ] Monitor logs for any reset password errors
- [ ] Verify users can successfully reset passwords
- [ ] Monitor for abuse attempts
- [ ] Check email delivery rates
- [ ] Gather user feedback

## Rollback Plan

If issues arise:
1. Comment out the route in `main.dart`
2. Comment out the button in `login_page.dart`
3. Deploy hot fix
4. Investigate issues
5. Reactivate after fix

## Important Notes

⚠️ **Before uncommenting code, ensure**:
- You're on branch `nj-ui-ux-dev-002`
- All changes are committed
- Supabase email settings are configured
- You've reviewed the spec document

⚠️ **Known Issues to Address**:
- OTP expiry time - verify Supabase default
- Password requirements - currently 6+ chars only
- No rate limiting visible - may want to add
- Email templates - verify they're configured

## Success Criteria

✅ Feature is considered complete when:
1. Users can successfully reset forgotten passwords
2. All error cases handled gracefully
3. No crashes or exceptions in logs
4. Works consistently across all platforms
5. Email delivery is reliable
6. No security issues identified

---

**Created**: January 4, 2026
**Branch**: nj-ui-ux-dev-002
**Status**: Ready for activation

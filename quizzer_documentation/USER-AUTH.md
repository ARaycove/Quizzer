# User Authentication & Logging Specification

## 1. Overview
This document specifies the authentication architecture for Quizzer. The system uses **Supabase Auth** as the backend identity provider. 
**Core Goal**: Provide secure, scalable user authentication while minimizing reliance on email delivery services (SMTP) for critical flows like password resets.

## 2. Current Architecture
- **Provider**: Supabase (via `supabase_flutter`).
- **State Management**: `SessionManager` (Singleton) and `UserAuth` class.
- **Persistence**: Sessions are persisted locally via Hive/SharedPreferences (platform dependent).
- **Logging**: All auth events are logged via `QuizzerLogger`.

## 3. Authentication Strategies
To minimize SMTP dependency, we implement a **Multi-Strategy** approach.

### 3.1. Phone Authentication (SMS OTP) - **Phase 1 Priority**
Passwordless login via One-Time Password sent to mobile.
- **Flow**: User enters Phone -> Receives SMS -> Enters Code -> Logged In.
- **Pros**: High delivery rate, no passwords.
- **Cons**: Cost per SMS (via Twilio/MessageBird integrated with Supabase).

### 3.2. Google OAuth (Phase 2)
This is the secondary method to avoid password management.
- **Flow**: Direct redirection to Google Sign-In.
- **Pros**: No passwords to lose, no SMTP needed, verified email automatically.
- **Implementation**:
  - Enable Google Provider in Supabase Dashboard.
  - Add SHA-1 keys for Android (in `android/app/build.gradle`).
  - Use `native_google_sign_in` or standard Supabase web-view flow.

### 3.3. Email & Password (Legacy/Standard)
Maintained for users who prefer explicit credentials.
- **Constraint**: Strict validation on client-side.
- **Risk**: Password reset requires a delivery mechanism.

## 4. Password Reset Specification (No-SMTP Strategy)
The core requirement is to handle password resets without relying on email links/codes.

### Proposed Solution: "Verified Identity" Reset
Instead of sending an email, we verify identity through an alternative channel before allowing a password update.

#### Option A: SMS OTP Backup (Preferred)
*Prerequisite*: User must add a confirmed phone number to their account.
1.  **Request**: User clicks "Forgot Password".
2.  **Challenge**: System detects linked phone number and sends SMS OTP.
3.  **Verify**: User enters SMS OTP.
4.  **Action**: User is authenticated temporarily and redirected to `UpdatePasswordPage`.

#### Option B: Google Identity Link
1.  **Request**: User clicks "Forgot Password".
2.  **Action**: User is prompted/forced to **Sign in with Google** using the same email address.
3.  **Merge**: Supabase detects the email match and logs the user in.
4.  **Result**: User provides no new password; they imply conversion to Google Auth.

#### Option C: Manual/Admin Reset (Fallback)
For users with NO phone and NO Google account execution:
1.  User contacts support.
2.  Admin generates a temporary password or magic link manually.

## 5. Implementation Details

### 5.1. Update `ResetPasswordPage`
The current `00_login_page` and `api` need to be updated. The file `lib/UI_systems/11_reset_password_page/reset_password_page.dart` (currently commented out/draft) should be revived with the following state machine:

**State 1: Identification**
- Input: Email or Phone.
- Action: Check valid providers for this user (Supabase `admin.getUser`).

**State 2: Verification (The "No-Email" path)**
- If `Phone` exists: Send SMS OTP.
- If `Google` exists: Prompt "Sign in with Google to reset".
- If `Only Email`: Show warning "As you have no backup recovery method, please contact support" OR (if SMTP is enabled) "Send magic link".

**State 3: New Credential**
- Input: New Password (x2).
- Action: `supabase.auth.updateUser({ password: newPassword })`.

### 5.2. Logging Requirements
All auth events must be structured in `QuizzerLogger`:
- `AUTH_LOGIN_ATTEMPT`: { method: 'email'|'google', user: 'hash' }
- `AUTH_LOGIN_SUCCESS`: { latency: ms }
- `AUTH_LOGIN_FAILURE`: { reason: 'invalid_pass'|'network' }
- `AUTH_pass_RESET_REQ`: { method_attempted: 'sms' }

## 6. Action Plan Status

### Phase 1: Phone Authentication (IMPLMENTED - Jan 2026)
**Configuration**: Supabase Phone Provider using **Twilio Verify**.
**Status**: ✅ Complete

1.  **Backend**: `UserAuth.dart` updated with `signInWithPhone` (sends OTP) and `verifyPhoneOtp` (verifies & logs in).
2.  **UI**: `ResetPasswordPage` implemented with 3-step state machine:
    *   **Step 0**: User enters phone number.
    *   **Step 1**: User enters 6-digit SMS OTP.
    *   **Step 2**: Authenticated user updates password via Supabase `updateUser`.
3.  **Infrastructure**:
    *   Supabase "Phone" provider enabled.
    *   Linked to Twilio Verify Service (SID: `VAf8...`) via Account SID/Auth Token.
    *   Sender ID managed automatically by Twilio Verify.

### Phase 2: Google Authentication (Next)
**Status**: ⬜ Pending

4.  **Enable Google Auth** in Supabase & Android Project (add SHA-1 keys).
5.  **Update `UserAuth.dart`**: Implement `signInWithGoogle()` flow.

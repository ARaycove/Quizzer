# Quizzer UI/UX Requirements Specification

**Version:** 1.0.0  
**Date:** December 18, 2025  
**Branch:** `feature/nj-ui-ux-dev`  
**Author:** Quizzer Development Team


This is really a two part spec, one for the dark theme UI/UX system and the other for the User Profile spec.

---

## 1\. Dark Theme System

### 1.1 Objectives

- Implement a cohesive, professional dark theme using Material 3  
- Centralize color control to eliminate ad-hoc widget-level colors  
- Use turquoise (or other) as a strategic accent, not a dominant UI color  
- Create maintainable, tunable theme system

### 1.2 Technical Requirements

#### Color Palette Structure

```dart
class AppColors {
  // Primary Accent Colors
  static const bingBlue = Color(0xFF4d87f2);          // Primary brand color
  static const powOrange = Color(0xFFfc9000);         // Secondary accent
  static const powOrangeDark = Color(0xFFb85a02);     // Dark variant
  static const radScarlet = Color(0xFFb25d7a);        // Tertiary accent
  
  // Neutral Greys (Dark Theme)
  static const dingBrightGrey = Color(0xFFd1d1d1);    // Input backgrounds, light elements
  static const dingLightGrey = Color(0xFFa3a8ae);     // Secondary text, borders
  static const dingLineGrey = Color(0xFF292929);      // Dividers, subtle borders
  static const dingMidGrey = Color(0xFF212121);       // Primary text on light backgrounds
  static const dingDarkGrey = Color(0xFF121212);      // Deep background
  
  // Supporting Colors
  static const duffLightBlue = Color(0xFFbce0fb);     // Info states, highlights
  static const duffLightGreen = Color(0xFFc9efb7);    // Success states
  
  // Semantic (Legacy - to be replaced)
  static const error = Color(0xFFCF6679);
  static const success = Color(0xFF81C784);

  

  // Text

  static const textPrimary \= Color(0xFFE8E8E8);  // Off-white (not pure white)

  static const textSecondary \= Color(0xFFB0B0B0);

}

#### Theme Implementation

- **Current File:** [`lib/app_theme.dart`](http://../../quizzer/lib/app_theme.dart) (already exists)  
- **Current Status:**  
  - Already uses `ThemeData.dark()` with `useMaterial3: true`   
  - Primary accent: `Color(0xFF87CEEB)` (light blue from logo)  
  - Secondary accent: `Color(0xFF98FB98)` (light green from logo)  
  - Background: `Color(0xFF0A1929)` (dark blue)  
  - Widgets already using `Theme.of(context).colorScheme.*`   
- **Strategy:** Refine existing theme, not create from scratch  
- **Material 3:** Already enabled 

#### Component Overrides

ThemeData.dark().copyWith(

  useMaterial3: true,

  colorScheme: ColorScheme.dark(

    surface: AppColors.surface,

    background: AppColors.bg,

    primary: AppColors.primaryAccent,

    // ... complete scheme

  ),

  textTheme: \_textTheme,

  appBarTheme: \_appBarTheme,

  cardTheme: \_cardTheme,

  inputDecorationTheme: \_inputDecorationTheme,

)

### 1.3 Design Rules

**DO:**

- Use blue for: primary buttons, selected states, active toggles, small highlights  
- Use surface elevation/containers for visual hierarchy  
- Reference colors via `Theme.of(context).colorScheme.*`  
- Keep text contrast ratios ≥ 4.5:1 (WCAG AA)

**DON'T:**

- Hardcode colors in widgets (`color: Colors.grey[900]`) *unless its an easter egg*  
- Use light grey for body text  
- Create high-contrast color blocks everywhere  
- Add new colors without updating `AppColors`

### 1.4 Tuning Parameters

Create 6–10 palette constants maximum. Focus tuning on:

1. Surface separation (subtle lightness differences)  
2. Text contrast (soften body text to off-white)  
3. Accent saturation (mute turquoise slightly in dark mode)  
4. Supporting accent (optional, limit to 1\)

### 1.5 Implementation Checklist

**Good News:** Theme system foundation already exists\! Focus on refinement.

- [x] ~~Create `app_theme.dart`~~ Already exists at [`lib/app_theme.dart`](http://../../quizzer/lib/app_theme.dart)  
- [x] ~~Enable Material 3~~ Already set: `useMaterial3: true`  
- [x] ~~Use `ColorScheme.dark()`~~ Already implemented  
- [ ] **Refine color palette:** Consider muting light blue accent slightly for dark mode  
- [ ] **Audit for hardcoded colors:** Search for `Color(0x`, `Colors.grey[`, etc.  
- [ ] **Replace hardcoded colors** with `Theme.of(context).colorScheme.*`  
      - Priority widgets: Question widgets, cards, containers  
      - Already good: Most question widgets use `Theme.of(context).colorScheme.primary`  
- [ ] **Add surface variants:** Define `surfaceContainerLow`, `surfaceContainerHigh` for elevation  
- [ ] **Build theme preview screen:** DevTools page showing all components  
- [ ] **Test on physical device:** Verify contrast ratios and color perception

---

## 2\. User Profile & Onboarding

### 2.1 Objectives

- Create Discord-like guided onboarding with progress tracking  
- Build editable profile page reusing onboarding components  
- Maintain privacy-forward data collection  
- Enable profile completion resumption

### 2.2 Data Model

#### UserProfile Database Schema

Based on the existing `user_profile` table (see [`lib/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart`](http://../../quizzer/lib/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart)):

// Core Identity (Required at registration)

final String uuid;                    // Primary key, auto-generated

final String email;                   // Required, unique

final String username;                // Required

final String role;                    // Default: 'base\_user'

final String accountStatus;           // Default: 'active'

final DateTime accountCreationDate;   // Auto-set at registration

final DateTime? lastLogin;            // Updated on login

// Profile Display (Optional \- collected in onboarding)

final String? profilePicture;         // Path/URL to avatar

//NJ \- NOTE some of these below are extra and need to be weeded out.

final String? nativeLanguage;         // Primary language

final String? secondaryLanguages;     // CSV list

final int? numLanguagesSpoken;

// Educational Context (Optional \- ML features)

final String? highestLevelEdu;        // e.g., "Bachelor's", "Master's"

final String? undergradMajor;

final String? undergradMinor;

final String? gradMajor;

final int? yearsSinceGraduation;

final String? educationBackground;    // JSON array

final int? teachingExperience;        // Years

// Socio-Cultural (Optional \- ML features, privacy-conscious)

final String? countryOfOrigin;

final String? currentCountry;

final String? currentState;

final String? currentCity;

final String? urbanRural;             // "urban", "suburban", "rural"

final String? religion;               // Optional

final String? politicalAffiliation;   // Optional

final String? maritalStatus;

final int? numChildren;

final int? veteranStatus;             // 0/1

// Demographics (Optional \- for ML personalization)

final String? birthDate;              // Stored as date string

final int? age;                       // Derived or self-reported

final String? birthOrder;             // "eldest", "middle", "youngest"

// Accessibility & Health (Optional \- never diagnostic)

final String? learningDisabilities;   // JSON array: \["ADHD", "Dyslexia"\]

final String? physicalDisabilities;   // JSON array for accessibility needs

final String? housingSituation;       // General descriptor

// Work Context (Optional \- ML features)

final String? currentOccupation;

final int? yearsWorkExperience;

final double? hoursWorkedPerWeek;

final int? totalJobChanges;

final double? householdIncome;        // Optional, ranges

// Learning Preferences (Set during onboarding)

final String? interestData;           // JSON: {subject: rating}

final String? notificationPreferences;// JSON: settings object

// Stats (Auto-generated, not user-input)

final double totalStudyTime;          // Default 0.0

final double? averageSessionLength;

// Sync Metadata (System-managed)

final int hasBeenSynced;              // 0/1

final int editsAreSynced;             // 0/1

final String? lastModifiedTimestamp;  // ISO8601

**See Also:** \[Chapter 08 \- Database Documentation\](../../quizzer\_documentation/Core Documentation/Chapter 08 \- Database/08\_02\_01\_User\_Profiles\_Table.md)

#### Privacy Constraints & Data Collection Philosophy

**Quizzer's Approach:** The database schema includes extensive optional fields for **ML-driven personalization** (see [`dataAnalysis/run_quizzer_ml_pipeline.py`](http://../../dataAnalysis/run_quizzer_ml_pipeline.py)). However, **UI/UX onboarding should only collect essential fields** and allow gradual opt-in.

**Never Require or Encourage:**

- Medical diagnoses, prescriptions, therapy notes, mental health details  
- Full date of birth (year is sufficient for age-based personalization)  
- Precise physical address (city/region sufficient)  
- Social Security Numbers, government IDs, insurance information  
- Income specifics (ranges acceptable if user chooses)  
- Freeform biography fields that may elicit sensitive disclosures

**Onboarding Should Collect (Prioritized):**

1. **Required:** Email, username (for account creation)  
2. **Strongly Encouraged:** Profile picture, native language, general education level  
3. **Optional (skip-friendly):** Interest areas, learning goals, notification preferences  
4. **Never in Onboarding:** Medical info, precise age, income, political/religious views

**Post-Onboarding (Gradual Opt-In):**

- Extensive demographic/educational fields available in "Advanced Profile Settings"  
- Clear explanations: "This helps our AI personalize your learning experience"  
- Always optional with "Skip" or "Prefer not to say" options  
- Disability fields framed as **accessibility preferences**, not medical history

### 2.3 Onboarding Workflow

#### Step Structure (MVP)

enum OnboardingStep {

  welcome,              // Welcome screen \+ privacy overview

  createIdentity,       // Required: username, optional: avatar

  setLanguageAndEdu,    // Optional: native language, education level

  selectInterests,      // Optional: subject interests (interest\_data)

  setNotifications,     // Optional: notification preferences

  finish                // Summary \+ profile completion status

}

**Note:** Account creation (email \+ auth) happens **before** onboarding via Firebase/Supabase authentication. Onboarding starts after successful registration.

#### Progress Calculation

progress \= completedRequiredSteps / totalRequiredSteps

// Display as: "Profile 60% complete"

#### Flow Behavior

1. **Linear wizard:** User progresses through steps sequentially  
2. **Skip allowed:** Optional steps have "Skip for now" button  
3. **Resume incomplete:** On finish, if required steps missing → redirect to first incomplete  
4. **Post-onboarding banner:** Profile page shows "Complete your profile (2 steps left)" with jump-to-wizard action

#### UI Components

- **Top progress bar:** Linear progress indicator  
- **Step cards:** Icon \+ title \+ description \+ CTA  
- **Finish screen:** Checklist with tap-to-jump navigation  
- **Skip button:** Visible on optional steps only

### 2.4 Profile Page Structure

#### Layout Sections

1. **Header Card**  
     
   - Avatar (circular, 80dp)  
   - Username (H5)  
   - Handle/tagline (optional, caption)  
   - Edit button (floating action or inline)

   

2. **About & Preferences**  
     
   - Goals (chip list)  
   - Reminder settings (compact row)  
   - Study schedule (calendar icon \+ text)

   

3. **Stats Card** *(stubbed for MVP)*  
     
   - Current streak (days)  
   - Total reviews (count)  
   - Accuracy (percentage)

   

4. **Badges/Power-ups** *(stubbed for MVP) \- LATER*  
     
   - Grid of locked badge cards  
   - "Coming soon" state

   

5. **Privacy Footer**  
     
   - Microcopy (2 lines max)  
   - Links: Privacy Policy, Terms, Data Controls

#### Privacy Microcopy

"We don't sell your data. Ever."

"We only use your profile to personalize your learning."

\[Privacy Policy\] \[Data Controls\]

### 2.5 Implementation Checklist

**Data Layer (Use Existing Infrastructure):**

- [ ] Review existing `user_profile_table.dart` schema (already comprehensive)  
- [ ] Create Dart model class wrapping database queries  
- [ ] Use existing `getDatabaseMonitor().requestDatabaseAccess()` pattern  
- [ ] Leverage existing `has_been_synced`/`edits_are_synced` fields for cloud sync  
- [ ] Profile picture: store path/URL in `profile_picture` field (already exists)  
- [ ] **Key Functions to Use:**  
      - `createNewUserProfile(email, username)` \- see \[`07_01_02_createNewUserProfile`\](../../quizzer\_documentation/Core Documentation/Chapter 07 \- Functions/Database Functions/07\_01\_02\_createNewUserProfile(email, username).md)  
      - `getUserIdByEmail(email)` \- already implemented  
      - `updateUserProfile(uuid, fieldMap)` \- to be created or use existing update patterns

**Onboarding Wizard:**

- [ ] Build step navigation controller with progress tracking  
- [ ] Create step screens:  
      - [ ] Welcome (privacy overview)  
      - [ ] Identity (username, avatar optional)  
      - [ ] Language & Education (native\_language, highest\_level\_edu)  
      - [ ] Interests (populate `interest_data` JSON field)  
      - [ ] Notifications (populate `notification_preferences` JSON)  
      - [ ] Finish (profile completion summary)  
- [ ] Implement skip/back/next logic (all steps after Identity optional)  
- [ ] Add resume-to-incomplete behavior  
- [ ] Calculate completion % based on filled optional fields

**Profile Page:**

- [ ] Build profile header using existing `uuid`, `username`, `profile_picture` fields  
- [ ] Display sections based on existing fields:  
      - [ ] Education: `highest_level_edu`, `undergrad_major`, `teaching_experience`  
      - [ ] Languages: `native_language`, `secondary_languages`, `num_languages_spoken`  
      - [ ] Stats: `total_study_time`, `average_session_length` (from database)  
      - [ ] Interests: Parse and display `interest_data` JSON  
- [ ] Reuse wizard components for edit mode  
- [ ] Add "Advanced Profile" section linking to full demographic fields  
- [ ] Implement completion banner showing % of optional fields filled

**Compliance & Privacy:**

- [ ] Add consent toggles for `notification_preferences`  
- [ ] Add "Prefer not to say" option for all optional demographic fields  
- [ ] Create Privacy Policy explaining:  
      - Why we collect optional data (ML personalization)  
      - User control (can skip/clear any field)  
      - Data retention (account deletion removes all profile data)  
- [ ] Plan data export (JSON dump of user's `user_profile` row)  
- [ ] Plan data deletion (existing account\_status \= 'deleted' or row removal)

---

## 3\. UI/UX Development Roadmap

### Completed Milestones ✅

**Theme Foundation (December 23-27, 2025)**
- ✅ Updated global color palette in `app_theme.dart`
  - Implemented BingBlue, PowOrange, RadScarlet, Ding*Grey variants
  - Added DuffLightBlue, DuffLightGreen for states
- ✅ Configured `ColorScheme.dark()` with new colors
- ✅ Updated all theme components (buttons, inputs, cards, dialogs, menus)
- ✅ Refactored login page to use theme colors exclusively
- ✅ Fixed text visibility (dark text on light input backgrounds)
- ✅ Adjusted button heights and padding
- ✅ Increased hint text size to 16.0 for readability
- ✅ Created font size constants (`tbLarge`, `tbMed`)
- ✅ Darkened input backgrounds (RGB 228 → 200 for better contrast)
- ✅ **Migrated to "Orbit Dark" theme (December 27, 2025)**
  - Unified neutral scale: bgCanvas, bgSurface, bgElevated, bgInput
  - Balanced accent colors: brandPrimary (Electric Mint #3ECF8E), chartBlue, chartPink, chartOrange
  - Typography system: textPrimary, textMuted, textDisabled
  - Eliminated visual vibration with cohesive grey scale
  - Updated all theme components to use new Orbit Dark palette

### Current Task 🎯

**Onboarding Wizard Implementation (Starting December 27, 2025)**
- [ ] Build step navigation controller with progress tracking
- [ ] Create welcome screen (privacy overview)
- [ ] Create identity screen (username, avatar upload)
- [ ] Create language & education screen
- [ ] Create interests selection screen
- [ ] Create notifications preferences screen
- [ ] Create finish/summary screen
- [ ] Implement skip/back/next navigation logic
- [ ] Add resume-to-incomplete behavior
- [ ] Calculate profile completion percentage
- [ ] Navigate to onboarding after successful registration

### Upcoming Tasks 📋

**Profile Page (Phase 2)**
- Build profile header with avatar display
- Create editable sections reusing wizard components
- Add stats card (stub with sample data)
- Implement "Complete your profile" banner
- Add privacy footer with policy links
- Enable edit mode (re-enter wizard for specific sections)

**Theme Refinement (Ongoing)**
- Build theme preview dev screen
- Audit remaining pages for hardcoded colors
- Test contrast ratios on physical device
- Accessibility audit (screen readers, touch targets)

**Advanced Features (Future)**
- Badges/achievements system
- Study schedule calendar
- Data export/deletion tools
- Advanced profile settings (demographic fields)
- Cloud sync integration for profiles

---

## 4\. Implementation Plan

### Phase 1: Theme Foundation (Week 1\) ✅ COMPLETED

1. Audit existing color usage  
2. Create `AppTheme` with `ColorScheme.dark()`  
3. Build theme preview dev screen  
4. Refactor top 10 most-used widgets

### Phase 2: Profile Data & Wizard (Week 2\) 🎯 IN PROGRESS

1. Implement `UserProfile` model \+ repository  
2. Build onboarding step screens  
3. Add progress tracking logic  
4. Test skip/resume flows

### Phase 3: Profile Page & Polish (Week 3\)

1. Build profile page UI  
2. Add stub sections (stats, badges)  
3. Integrate edit mode (re-enter wizard)  
4. Add privacy footer \+ links

### Phase 4: Testing & Refinement (Week 4\)

1. Dark theme tuning on physical devices  
2. Accessibility audit (contrast, font scaling)  
3. Onboarding UX testing (10 user sessions)  
4. Performance optimization

---

## 5\. Success Metrics

### Theme Quality

- Zero hardcoded colors outside `AppTheme`  
- WCAG AA contrast ratios (4.5:1+) for all text  
- \<5 tuning iterations to "feels polished"

### Onboarding Completion

- ≥70% users complete required steps  
- ≥50% users complete at least 1 optional step  
- \<10% abandon during wizard

### Profile Engagement

- ≥60% users edit profile within first week  
- ≥40% users return to complete missing steps

---

## 6\. Non-Functional Requirements

### Performance

- Theme switch: \<16ms (1 frame)  
- Profile load: \<200ms (cached)  
- Onboarding wizard: \<100ms per step transition

### Accessibility

- Screen reader support for all interactive elements  
- Minimum touch target: 48x48dp  
- Text scaling: 100%–200% without layout breaks

### Privacy & Security

- Profile data encrypted at rest  
- No telemetry without explicit consent  
- GDPR-compliant data deletion (stub prepared)

---

## 7\. References

- **Material 3 Design:** [https://m3.material.io](https://m3.material.io)  
- **WCAG Guidelines:** [https://www.w3.org/WAI/WCAG21/quickref/](https://www.w3.org/WAI/WCAG21/quickref/)  
- **Flutter Theme Documentation:** [https://api.flutter.dev/flutter/material/ThemeData-class.html](https://api.flutter.dev/flutter/material/ThemeData-class.html)  
- **Cognitive Load Principles:** See `quizzer_documentation/Core Documentation/Chapter 04/`

---

## 8\. Alignment with Existing Codebase

### Database Integration

- **User Profile Table:** Already comprehensive with 60+ fields (see [`user_profile_table.dart`](http://../../quizzer/lib/backend_systems/00_database_manager/tables/user_profile/user_profile_table.dart))  
- **Sync System:** `has_been_synced`, `edits_are_synced` fields \+ SwitchBoard signals already implemented  
- **Session Management:** [`session_manager.dart`](http://../../quizzer/lib/backend_systems/session_manager/session_manager.dart) tracks current user UUID

### ML Integration Points

- **Feature Vector:** User profile fields used in ML pipeline (see [`dataAnalysis/run_quizzer_ml_pipeline.py`](http://../../dataAnalysis/run_quizzer_ml_pipeline.py))  
- **Interest Data:** JSON field for subject ratings (drives question selection)  
- **Demographic Features:** Optional fields enhance personalization but never required

### UI System Integration

- **Theme:** [`app_theme.dart`](http://../../quizzer/lib/app_theme.dart) already uses Material 3 \+ ColorScheme  
- **Question Widgets:** Already reference `Theme.of(context).colorScheme.*` (good\!)  
- **Page Structure:** Place profile page in `lib/UI_systems/pages/` directory

### Backend Architecture

- **Database Monitor:** Use `getDatabaseMonitor().requestDatabaseAccess()` for all queries  
- **Logger:** Use `QuizzerLogger.logMessage()`, `logSuccess()`, `logError()` patterns  
- **Fail Fast:** Follow existing pattern \- throw exceptions, don't return nulls

### Documentation References

- \[Chapter 07 \- Functions\](../Core Documentation/Chapter 07 \- Functions/)  
- \[Chapter 08 \- Database\](../Core Documentation/Chapter 08 \- Database/)  
- \[Chapter 04 \- UI/UX Philosophy\](../Core Documentation/Chapter 04/)  
- \[Chapter 09 \- ML Algorithms\](../Core Documentation/Chapter 09 \- Algorithms and Background Processes/)

---

## 9\. Key Differences from Initial Proposal

This spec has been **aligned with the actual Quizzer codebase** and differs from generic approaches:

1. **Database Schema:** Uses existing 60+ field schema (not simplified MVP schema)  
2. **Theme System:** Refines existing `app_theme.dart` (not creating from scratch)  
3. **Privacy Approach:** Balances ML data needs with gradual opt-in UX  
4. **Onboarding Simplicity:** UI collects essentials; advanced fields available post-onboarding  
5. **Sync Infrastructure:** Leverages existing SwitchBoard \+ sync flags  
6. **Architecture Patterns:** Follows existing DatabaseMonitor \+ Logger patterns

**Bottom Line:** This spec respects the sophisticated backend while keeping the UX simple and privacy-forward.

---

**Document Status:** Draft → Review → Approved → In Progress  
**Last Updated:** December 18, 2025  
**Next Review:** December 25, 2025  
**Codebase Alignment Check:**  Completed  

**Nathans Notes:** 
flutter clean
flutter pub get

# Make sure the emulator is running (Pixel_2_API_28 / emulator-5554)
flutter devices

# Then run on the Android emulator
flutter run -d emulator-5554
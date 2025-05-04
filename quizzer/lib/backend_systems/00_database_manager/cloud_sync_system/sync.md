# Custom Sync Mechanism Overview

This document outlines the custom synchronization mechanism designed to integrate the local SQLite database with the external Supabase server, prioritizing offline-first operation.

## Current Progress

- **Outbound Sync for New Question-Answer Pairs:** Implemented. The `OutboundSyncWorker` successfully detects newly created question-answer pairs (`has_been_synced = 0`) and pushes them to the `question_answer_pair_new_review` table in Supabase for validation/review via an `INSERT` operation.

## Sync Plan & TODO Items

The overall sync process involves both pushing local changes out (outbound) and pulling remote changes in (inbound).

### Outbound Sync (Pushing Local Changes to Cloud)

The `OutboundSyncWorker` is responsible for pushing local data that needs synchronization to intermediary "review" tables or directly to main tables in Supabase.

**Worker Logic:**
- Listens to the local `SwitchBoard` for signals indicating potential sync needs (`onOutboundSyncNeeded`).
- Wakes up upon receiving signals.
- Checks network connectivity before attempting sync operations.
- Acquires database access via `DatabaseMonitor`.
- Iterates through tables/records marked for sync (checking flags like `has_been_synced`, `edits_are_synced`).
- Pushes records to the appropriate Supabase table using helper functions (like `pushRecordToSupabase`).
- Updates local sync flags (e.g., setting `has_been_synced=1`, `edits_are_synced=1`) upon successful push.
- Releases database access.

**Specific Table Sync TODOs (Outbound):**
1.  **Question-Answer Pairs (Edits):**
    -   **Trigger:** Local edit to a `question_answer_pairs` record (via `editQuestionAnswerPair`).
    -   **Action:** `editQuestionAnswerPair` sets `edits_are_synced = 0`.
    -   **Worker Task:** Detect records where `has_been_synced = 1` AND `edits_are_synced = 0`. Push the full record to `question_answer_pair_edits_review` table in Supabase. Update `edits_are_synced = 1` locally on success.
2.  **Question Answer Attempts:**
    -   **Trigger:** User submits an answer (`recordQuestionAnswerAttempt`).
    -   **Action:** Record is created locally in `question_answer_attempts`. **Need to add `has_been_synced` flag (INTEGER DEFAULT 0) to this table.**
    -   **Worker Task:** Add logic to `OutboundSyncWorker` to detect unsynced attempts (`has_been_synced = 0`), push to a `question_answer_attempts` table in Supabase (using `INSERT`). Update local `has_been_synced = 1`. (Requires Supabase table creation mirroring local schema).
3.  **Login Attempts:** (Details TBD - might be logged differently or not synced)
    -   **Trigger:** User attempts login.
    -   **Action:** Log attempt locally (table TBD, potentially `login_attempts`). **Need to define table and add `has_been_synced` flag.**
    -   **Worker Task:** Add logic to `OutboundSyncWorker` if syncing is desired. Push to a `login_attempts` table in Supabase. Update local sync flag. (Requires Supabase table creation).
4.  **User Question Answer Pairs (UQAP):**
    -   **Trigger:** Changes occur due to answering questions (streak, due date updated via `editUserQuestionAnswerPair`), potentially module activation/deactivation affecting associated UQAPs.
    -   **Action:** Local `user_question_answer_pairs` record is updated. **Need to add `has_been_synced` flag (INTEGER DEFAULT 0) to this table.** The update function should set this flag to 0.
    -   **Worker Task:** Add logic to `OutboundSyncWorker` to detect unsynced UQAP records (`has_been_synced = 0`). Push the *entire* current state of the record to a corresponding `user_question_answer_pairs` table in Supabase (likely using `upsert` based on composite key `user_id` and `question_id`). Update local `has_been_synced = 1`. (Requires Supabase table creation mirroring local schema).
5.  **User Profile:**
    -   **Trigger:** Changes to user profile fields (e.g., interests, settings, module activations, tutorial progress).
    -   **Action:** Local `user_profile` record is updated via specific functions (e.g., `updateModuleActivationStatus`, `updateTutorialProgress`). **Need to add `has_been_synced` flag (INTEGER DEFAULT 0) to this table.** Update functions should set this flag to 0.
    -   **Worker Task:** Add logic to `OutboundSyncWorker` to detect unsynced user profile (`has_been_synced = 0`). Push the *entire* current state of the record to the `user_profile` table in Supabase (using `upsert` based on `uuid`). Update local `has_been_synced = 1`. (Requires Supabase table creation mirroring local schema).

**Note on Modules:** Module records (`modules` table) are constructed locally based on `question_answer_pairs` and user profile data; they are not directly synced. Module *activation status* is synced via the `user_profile` table.

### Inbound Sync (Pulling Cloud Changes to Local)

An `InboundSyncWorker` (to be created) will be responsible for listening to changes in the *main* Supabase tables (not the review tables) and updating the local database accordingly. This worker will handle bringing down reviewed/approved questions, updated user profiles, etc.

**Worker Logic (High-Level):**
- Subscribes to real-time changes (or periodically polls) relevant Supabase tables (e.g., `question_answer_pairs`, `user_question_answer_pairs`, `user_profile` after review/approval).
- Receives change events (INSERT, UPDATE, DELETE).
- Acquires database access via `DatabaseMonitor`.
- Applies the corresponding change to the local SQLite database using helper functions (`insertRawData`, `updateRawData`, `delete`), ensuring conflict resolution (e.g., checking timestamps, preferring remote data if newer).
- Releases database access.

**Specific Table Sync TODOs (Inbound):**
- Create `InboundSyncWorker` class structure.
- Implement Supabase real-time subscription or polling logic.
- Implement local update logic for `question_answer_pairs` (handling new/updated questions from the main cloud table).
- Implement local update logic for `user_question_answer_pairs` (handling remote changes to user progress).
- Implement local update logic for `user_profile` (handling remote changes to profile data).
- Define and implement conflict resolution strategies (e.g., last-write-wins based on a reliable timestamp).

# async workers
## Outbound Async Worker
- listens to the local switchboard for new entries as they are made
- wakes up upon these signals
- looks for has_been_synced tag in all records
- if has_been_synced == 0
    - sends the record to the cloud DB
    - Some records will need validation, so all this worker does is ensure that fresh workers get sent to their proper intermediary location so the next service can validate or confirm

## Inbound Async Worker
- listens to Supabase changes


# login_attempts


# Question Answer Pairs
- fresh pairs get synced right away

- if a pair is edited locally, the question should 

# User Question Answer Pairs

# Question Answer Attempts



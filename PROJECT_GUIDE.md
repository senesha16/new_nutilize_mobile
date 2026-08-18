# Nutilize Mobile Project Guide

This document is a system reference for future debugging, fixes, and build recovery. It is meant to preserve the working behavior of the app and reduce repeated prompting when something breaks.

## 1. Project purpose
This is a Flutter mobile app for Nutilize that supports:
- user authentication
- room reservation requests
- item borrowing requests
- approval flows
- inventory tracking
- reservation history/calendar visibility
- Supabase-backed persistence and notifications

The app is not a generic template. It has a custom reservation/inventory workflow tied to the backend schema and business rules.

## 2. Core architecture

### App structure
- `lib/main.dart` – app entry point
- `lib/home.dart` – main app screens and state hosting
- `lib/calendar.dart` – calendar/history display logic
- `lib/request.dart` – request-related UI and flow coordination
- `lib/loading_screen_page.dart` – startup/loading screen
- `lib/features/` – feature modules for auth, calendar, home, notifications, request, user
- `lib/services/` – business logic and backend helpers
- `lib/widgets/` – reusable UI shell/components

### Main service layer
- `lib/services/auth_service.dart`
  - user login/signup logic
  - session restoration
  - profile loading
  - user_id resolution
  - program/affiliation mapping

- `lib/services/reservation_service.dart`
  - core reservation business logic
  - item availability checks
  - room conflict checks
  - approval chain generation
  - inventory/unit reservation logic
  - reservation and item creation
  - user-scoped fetch logic

- `lib/services/supabase_service.dart`
  - Supabase configuration and service-role fallback usage

### Shared state stores
- `ReservationActivityStore`
  - holds current reservation records
  - used by calendar/history display

- `NotificationActivityStore`
  - holds notifications
  - used by app shell refresh and snackbar notifications

### UI shells and navigation
- `lib/widgets/app_shell.dart`
  - main shell
  - refresh loop
  - realtime subscription setup
  - notification handling

- `lib/widgets/app_shell_scope.dart`
  - app-scoped state helpers

- `lib/widgets/app_header.dart`, `secondary_header.dart`, `app_bottom_nav.dart`
  - layout and navigation chrome

## 3. Business rules to preserve
These are the rules that should not be broken during future fixes.

### Reservation logic
- Reservations are not just aggregate counts; they are tied to item units.
- Each item has physical units in `item_units`.
- A reservation reserves specific available unit IDs.
- Availability depends on both:
  - whether the unit is marked available
  - whether there are time conflicts for the same reservation window

### Approval logic
- Reservation approvals follow an approval chain and depend on room/item conditions.
- The app calculates approval order dynamically.
- Approval ordering should respect insertion/creation order rather than arbitrary sorting.

### Inventory logic
- `usage` values must not go negative.
- Inventory display should clamp usage into a valid range, e.g. `0..total`.
- Negative values like `-3/280` should be normalized to `0/280` or equivalent valid display output.

### User visibility logic
- Reservation records must be filtered to the logged-in user.
- The app should not show records from another user in calendar/history.
- This applies to both current-user queries and realtime UI refreshes.

### Session logic
- On refresh, session/user state should be restored before loading user-specific reservation data.
- If `user_id` is temporarily null, the app should not query partial data or show wrong records.

## 4. Exact business workflow
This section is the clearest summary of how the app is expected to behave and should be preserved.

### Borrowing flow
1. User chooses a room or standalone item request.
2. User picks the item(s) to borrow and enters the quantity for each item.
3. The app validates each requested quantity against available stock.
4. The app checks if the requested units are actually available in the relevant time window.
5. The app creates reservation records and links the selected item units to that reservation.
6. The app updates item unit statuses to `in_use` once reserved.
7. The app records the reservation in the reservation list for the logged-in user only.

### Approval flow
1. A request is created and begins in a pending state.
2. The app calculates the approval chain based on the request type and relevant rules.
3. Approval ordering follows the app’s dynamic logic and should preserve insertion/creation order.
4. Pending/approved/completed reservations block inventory availability.
5. Cancelled/rejected/denied/returned reservations do not block availability.
6. Approval status changes feed the realtime notifications and refresh the user-visible reservation data.

### Inventory flow
- `total` is the total number of units for an item.
- `usage` should never be negative.
- usage should be clamped to a valid range before display.
- reservation logic should reduce available units based on reserved physical units, not just a flat count.
- unit statuses must be updated correctly when a reservation is created, approved, or cancelled.

### Calendar/history flow
- the app loads the user’s own reservation records only
- the visible calendar/history list should exclude records created by other users
- realtime updates and refreshes must preserve this scoping

## 5. Known working patterns
These are the implementation patterns that already work and should be preserved.

### Item quantity selection
The app supports selecting quantities for borrowable items instead of simple checkbox selection.
- item quantities are stored as a `Map<int, int>` where key is item_id and value is quantity
- validation checks requested quantity against available quantity before submit
- at least one quantity must be valid and within inventory bounds

### Reservation submission loading pattern
- submit actions should show a loading indicator
- the submit button should be disabled while submitting
- this prevents duplicate submission or race conditions

### User-scoped filtering pattern
- any combined reservation fetch should filter by resolved `currentUserId`
- before adding records to the visible list, ensure `reservation.userId == currentUserId`

## 6. Critical backend assumptions
This app assumes these backend entities/concepts exist and are used in a specific way.

### Authentication
- Supabase auth session is the source of the active login state.
- Profile data is resolved from auth + user profile tables.
- The app maps profile labels and affiliations to internal numeric IDs.

### Reservation tables
The app depends on tables such as:
- `reservations`
- `reservation_items`
- `reservation_item_units`
- `reservation_rooms`
- `reservation_approvals`
- `item_units`
- `items`
- `rooms`

### Reservation states
Blocking/active states used in logic include statuses such as:
- Pending Approval
- Approved
- Completed

Non-blocking statuses include cases such as:
- Cancelled
- Rejected
- Denied
- Returned

## 6. Important implementation notes

### Do not redesign the app around new patterns unless the root cause is proven
If a bug arises, prefer targeted fixes over broad refactors.

### Preserve the service-layer business rules
The `reservation_service.dart` logic is the core of the app’s business model. Do not replace it with generic logic unless the root cause requires it.

### Preserve existing user identity semantics
User scoping and profile restoration are critical. Do not treat reservations as global or shared across users.

### Preserve the app blue/yellow visual language
The project prefers the existing blue/yellow material language and minimal UI changes.

## 7. Build and dependency status
### Known issue pattern
The Android release build has hit dependency/toolchain issues related to Gradle/Kotlin compatibility and plugin versions.

This is not a core app logic problem. It is a packaging/build-system issue.

### Safe rule for future debugging
When build problems occur:
1. do not rewrite app features first
2. isolate whether the failure is in app code or Android build configuration
3. fix the build system only if the issue is external to app logic
4. keep business logic untouched unless evidence proves otherwise

### Preferred build fix strategy
- use the current Flutter stable toolchain version
- avoid random dependency overrides
- prefer targeted Android build config compatibility adjustments
- do not change app logic while chasing a Gradle error

## 8. Release readiness goal
The app should eventually produce a valid Android App Bundle for Google Play without harming the working reservation/inventory flow.

Until that happens, the app should be treated as:
- working functionally in the app environment
- blocked only by Android packaging/toolchain compatibility

## 9. Minimal future fix guidance
If a future agent is asked to fix the app after a build break, they should follow this order:

1. Read this file first
2. Preserve all known business rules
3. Confirm whether the issue is app-code or build-toolchain
4. Fix the build issue without touching reservation logic
5. Verify app behavior with minimal targeted tests
6. Rebuild AAB only once the build system is compatible

## 10. Summary
The working system should be treated as a business workflow system with the following core truths:
- reservations are user-scoped
- inventory is unit-based
- approval flow is dynamic and important
- user session state matters
- app logic must remain intact while Android packaging issues are solved separately

This guide exists to reduce repeated prompting and allow future fixes to anchor on the actual app architecture and intended behavior instead of restarting from zero.

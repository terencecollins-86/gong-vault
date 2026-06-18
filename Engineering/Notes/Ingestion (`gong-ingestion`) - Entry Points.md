# Ingestion (`gong-ingestion`) — Entry Points

> **Repo:** `gong-ingestion` | **Owner:** `ariel.bloch@gong.io` | **Sentry team:** `mail-cal-ingestion`

The ingestion group is split into discrete deployable modules. Each runs as an independent `api-server` pod.

| Module | Type | Domain |
|---|---|---|
| `IngesterCalendarSupervisor` | api-server | Calendar lifecycle orchestration |
| `GoogleCalendarIngester` | api-server | Google Calendar event polling/push |
| `OfficeCalendarIngester` | api-server | Office 365 Calendar event polling |
| `MeetingsIndexer` | api-server | Meeting indexing / CRM association |
| `GoogleMailProcessingServer` | api-server | Gmail message processing |
| `MailListener` | api-server | Mail Kafka consumer + mail supervisor |

---

## High-Frequency / Automated Entry Points

These run constantly without human triggering — the most active paths in the system.

### 1. Kafka: `MailIngestionResultsConsumer`

**Module:** `MailListener` (IngesterMailSupervisor)  
**File:** `Mail/IngesterMailSupervisor/.../kafka/MailIngestionResultsConsumer.java`  
**Trigger:** Kafka topic — ingestion result events from `GoogleMailProcessingServer`  
**Interface:** `ResultBasedMultipleRecordConsumer<IngestionResult>`

Processes batch results from mail ingestion workers. On each record it:
- Updates mailbox status (`MailboxStatusHandler`)
- Validates job uniqueness (`JobUniquenessValidator`)
- Fans out to sub-handlers: `PurgeOldEmailsAckConsumer`, `DeleteBlackListedMailsAckConsumer`, `CompanyMailReprocessAckConsumer`, `DeleteAppUserDeniedListedMailsAckConsumer`

```
Payload: ConsumerRecord<String, IngestionResult>
  - companyId: long
  - id: String (job ID)
  - completionState: IngestionResult.CompletionState
```

---

### 2. Kafka: `IngesterSyncStatusConsumer`

**Module:** `MailListener` (IngesterMailSupervisor)  
**File:** `Mail/IngesterMailSupervisor/.../kafka/IngesterSyncStatusConsumer.java`  
**Trigger:** Kafka topic — grouped sync status update events  
**Interface:** `SingleRecordConsumer<GroupedGongEvents<IngesterSyncStatusUpdate>>`

Consumes connectivity/sync status updates from mail ingestion workers and persists them in a single transaction via `IngestionSyncStatusService`.

```
Payload: ConsumerRecord<Long, GroupedGongEvents<IngesterSyncStatusUpdate>>
  - list of IngesterSyncStatusUpdate records sorted by timestamp
```

---

### 3. Scheduled: `ImportGoogleCalendarEventsTask`

**Module:** `IngesterCalendarSupervisor`  
**Bean:** `ImportCalendarTasks#ImportGoogleCalendarEventsTask()`  
**Trigger:** `@Scheduled` — cron-based, polls all Google Workspace companies  

Iterates all Google-connected companies via `ProviderCompaniesImporter` and dispatches calendar import jobs over Kafka (`CalendarIngesterKafkaConfig`). Relies on `GoogleAppsAuthService` for OAuth tokens.

---

### 4. Scheduled: `ImportOfficeCalendarEventsTask`

**Module:** `IngesterCalendarSupervisor`  
**Bean:** `ImportCalendarTasks#ImportOfficeCalendarEventsTask()`  
**Trigger:** `@Scheduled` — cron-based, polls all Office 365 companies  

Same pattern as above but for Office 365. Uses `OfficeAzureUsersService` to enumerate users.

---

### 5. Scheduled: `UpdateAzureUsers`

**Module:** `IngesterCalendarSupervisor`  
**Bean:** `ImportCalendarTasks#UpdateAzureUsers()`  
**Trigger:** `@Scheduled` — periodic refresh  

Syncs Azure AD user lists for Office 365 companies so calendar import has up-to-date user rosters.

---

## Operational REST Entry Points

These are called by other services or scripts during normal system operation.

### 6. `POST /...` — Calendar Requests (v2, primary)

**Controller:** `IcsCalendarRequestsController`  
**Module:** `IngesterCalendarSupervisor`  
**File:** `Calendar/IngesterCalendarSupervisor/.../rest/v2/IcsCalendarRequestsController.java`  
**Implements:** `CalendarRequestsApi`

The current (non-deprecated) calendar lifecycle controller. All callers should prefer this over the v1 and deprecated variants.

| Endpoint | Method | Purpose |
|---|---|---|
| deactivateMeetingsForUser | POST | Deactivate/delete meetings for a single user |
| deactivateMeetingsForCompany | POST | Deactivate/delete meetings for a whole company |
| deleteMeetingsById | POST | Delete specific meeting IDs |
| permanentlyDeleteMeetings | POST | Hard-delete a specific meeting |
| createMeetingBackfillTask | POST | Create a backfill task for a user/company/provider |
| deleteMeetingBackfillTaskForUser | POST | Remove backfill task by userId |
| deleteMeetingBackfillTaskForCompany | POST | Remove backfill task by companyId |
| isCalendarImportEnabledForUser | GET | Check if calendar import is active for a user |

```
Key params (shared across most endpoints):
  companyId: long
  userId: long
  provider: String (e.g. "GOOGLE", "OFFICE365")
  deleteFromDateTime: Instant (ISO-8601)
  shouldImportCalls: boolean
  shouldImportNonRecordedMeetings: boolean
```

---

### 7. `POST /...` — Calendar Requests (v1)

**Controller:** `CalendarRequestsController`  
**Module:** `IngesterCalendarSupervisor`  
**File:** `Calendar/IngesterCalendarSupervisor/.../rest/CalendarRequestsController.java`

Identical capabilities to `IcsCalendarRequestsController` (v2) but without the `CalendarRequestsApi` contract. Prefer v2 for new integrations.

---

### 8. `POST /...` — Mail Import Trigger (v2, primary)

**Controller:** `ImsMailImportController`  
**Module:** `IngesterMailSupervisor`  
**File:** `Mail/IngesterMailSupervisor/.../rest/mail/v2/ImsMailImportController.java`  
**Implements:** `MailImportApi`

| Endpoint | Method | Purpose |
|---|---|---|
| triggerCompanyReimportFromMailboxProvider | POST | Reset company mail import state to force a full re-scan |

```
Params:
  companyId: long
```

Resets the mailbox import state by calling `MailboxDao#deleteCompanyMailImportState`, which causes the next scheduled scan to reimport from scratch.

---

### 9. `POST /...` — Mail Import Trigger (v1)

**Controller:** `IngesterMailSupervisorMailImportController`  
**Module:** `IngesterMailSupervisor`  
**File:** `Mail/IngesterMailSupervisor/.../rest/mail/IngesterMailSupervisorMailImportController.java`

Same as v2 above. Prefer `ImsMailImportController` (v2) for new callers.

---

### 10. `GET/POST /...` — Calendar Mirror Invalidation

**Controller:** `CalendarMirrorController`  
**Module:** `IngesterCalendarSupervisor`  
**File:** `Calendar/IngesterCalendarSupervisor/.../rest/CalendarMirrorController.java`

Invalidates meeting entries in the MongoDB calls mirror. Called when data integrity requires forcing a re-index.

| Endpoint | Method | Purpose |
|---|---|---|
| deleteUserCallsFromMirror | POST | Remove user's calls from mirror |
| deleteUserCallsAndInterviewsFromMirror | POST | Remove calls + interviews for a user |
| invalidateCompanyMeetings | POST | Invalidate all meetings for a company |
| invalidateUsersMeetings | POST | Invalidate meetings for a set of users |
| invalidateMeetingsByMeetingId | POST | Invalidate by meeting ID set |
| invalidateMeetingsByProviderEventId | POST | Invalidate by provider event ID set |

```
Params:
  companyId: long
  appUserId: long (user-scoped endpoints)
  meetingIds / providerEventIds: Set<String>
```

---

### 11. `GET/POST /...` — Admin Fallback

**Controller:** `AdminFallbackController`  
**Module:** `IngesterCalendarSupervisor`  
**File:** `Calendar/IngesterCalendarSupervisor/.../rest/AdminFallbackController.java`

Manages the "admin fallback" feature — controls whether a company falls back to admin-level calendar access.

| Endpoint | Method | Purpose |
|---|---|---|
| isAdminFallbackEnabledForCompany | GET | Check if admin fallback is active |
| disableAdminFallbackEnabledForCompany | POST | Disable admin fallback (also deletes sync status) |

```
Params:
  companyId: long
```

---

### 12. `POST /...` — AppUser Email Mapping (Calendar)

**Controller:** `AppUserMappingsController` (`com.honeyfy.ingester.calendar.supervisor.rest`)  
**Module:** `IngesterCalendarSupervisor`  
**File:** `Calendar/IngesterCalendarSupervisor/.../rest/AppUserMappingsController.java`

Maps an email address to an `appUserId` / workspace ID. Used by calendar ingestion workers to resolve identities.

```
POST /...
Body: AppUserMappingsRequest { emailAddress: String, ... }
Returns: AppUserMappingsResponse { appUserId: long, workspaceId: ... }
```

---

### 13. `POST /...` — AppUser Email Mapping (Mail)

**Controller:** `AppUserMappingsController` (`com.honeyfy.ingester.mail.supervisor.rest.user`)  
**Module:** `IngesterMailSupervisor`  
**File:** `Mail/IngesterMailSupervisor/.../rest/user/AppUserMappingsController.java`

Same contract as the calendar variant, but served from the mail supervisor module.

---

## Deprecated Entry Points

### 14. `POST/GET /...` — Calendar Deletion Requests (deprecated)

**Controller:** `CalendarDeletionRequestsController`  
**Module:** `IngesterCalendarSupervisor`  
**Annotation:** `@Deprecated`

Superseded by `IcsCalendarRequestsController` (v2). Do not add new callers.

| Endpoint | Method |
|---|---|
| createCompanyCalendarDelayedDeletionRequest | @RequestMapping |
| permanentlyDeleteMeetings | @RequestMapping |
| createUserCalendarDelayedDeletionRequest | @RequestMapping |
| deleteMeetingsById | @RequestMapping |

---

## Troubleshooting / Internal Ops Entry Points

These are low-frequency, internal-tools-facing endpoints. Not called in normal production flows.

### 15. Google Calendar Troubleshooting

**Controller:** `TroubleshootingGoogleCalendar`  
**Module:** `IngesterCalendarSupervisor`

| Endpoint | Method | Purpose |
|---|---|---|
| queryRawEvents | POST | Fetch raw Google Calendar events for a user |
| queryAuthenticatingUser | POST | Check which Google account is authenticating |
| queryPerson | POST | Lookup a person from Google Directory |
| queryUserCalendars | POST | List all calendars for a user |
| queryUserSecondaryCalendarIds | POST | List secondary calendar IDs |
| queryConvertedEvents | GET | Get converted (processed) events for a user |
| updateImportCompanyNonRecordedMeetings | POST | Toggle non-recorded meeting import setting |

```
Common params:
  companyId: long
  emailAddress: String
  from / to: Optional<Date>
```

---

### 16. Office 365 Calendar Troubleshooting

**Controller:** `TroubleshootingOffice365Integration` (`calendar` package)  
**Module:** `IngesterCalendarSupervisor`

| Endpoint | Method | Purpose |
|---|---|---|
| listGroups | GET | List O365 groups for a company |
| listUsers | GET | List O365 users |
| listSharedCalendars | GET | List shared calendars |
| addUser | POST | Manually add an Azure user |
| updateAzureUserList | POST | Force-refresh Azure user list |
| fillCompanyIdInAppuserSyncStatus | POST | Backfill companyId in sync status records |
| fillCompanyIdInAppuserSettings | POST | Backfill companyId in appuser settings |
| updateImportCompanyNonRecordedMeetings | POST | Toggle non-recorded meeting import |
| listUserGroups | GET | List groups for a specific user |
| listGroupEvents | GET | List calendar events for a group |

---

### 17. Office 365 Mail Troubleshooting

**Controller:** `TroubleshootingOffice365Integration` (`mail` package)  
**Module:** `IngesterMailSupervisor`

| Endpoint | Method | Purpose |
|---|---|---|
| continueResumeLink | GET | Resume an O365 delta-sync link |
| disconnect | GET | Disconnect an O365 company mail integration |

---

### 18. Mail Ingestion Troubleshooting

**Controller:** `TroubleshootingMailIngestion`  
**Module:** `IngesterMailSupervisor`

| Endpoint | Method | Purpose |
|---|---|---|
| listAllPossibleEmails | GET | List all email addresses for a user |
| getEmailToActiveUserMap | GET | Get email → active user map for a company |
| ingestSingleEmail | GET | Force-ingest a single email by provider message ID |

```
Key params for ingestSingleEmail:
  providerCode: MailboxProviderCode (GMAIL, OFFICE365)
  providerMessageId: String
  companyId: long
  appUserId: long
  isCompanyCredentials: boolean
  isLowPriority: boolean
```

---

### 19. Mailbox Import Operations

**Controller:** `TroubleshootingMailboxImport`  
**Module:** `IngesterMailSupervisor`

| Endpoint | Method | Purpose |
|---|---|---|
| getFetchEmailsNewerThanDaysSettings | GET | Get per-company max email age settings |
| triggerCompaniesReimportFromMailboxProvider | POST | Trigger reimport for multiple companies (comma-separated) |
| triggerAppuserInitialSyncFromMailboxProviderExp | POST | Trigger initial sync for a single user with date range |
| triggerAppuserInitialSyncForRequestedNumberOfDaysFromMailboxProvider | POST | Trigger initial sync for N days back |
| updateCompanySettingFetchEmailsNewerThanDays | POST | Update per-company max fetch age |
| triggerAppUserReimportFromMailboxProvider | POST | Reimport for a single user |
| submitCompanyMailImportJob | POST | Directly submit a company-wide mail import job |
| submitBulkMailImportJob | POST | Submit mail import jobs from a CSV file |
| submitMailImportJobAck | POST | Manually ack a mail import job completion |
| findMailMessagesImportStatus | GET | Check import status for a user's mailbox |

---

### 20. Ingester Task Management

**Controller:** `TroubleshootingIngesterTaskController`  
**Module:** `IngesterMailSupervisor`

Manages named scanning tasks (e.g. purge pipelines) stored in the ingester task table.

| Endpoint | Method | Purpose |
|---|---|---|
| getAllScanningTasks | POST | List all tasks across all task types |
| getScanningTasksByName | POST | Filter tasks by `IngesterTaskName` |
| getScanningTasksByNameAndStatus | POST | Filter by name + `IngesterTaskStatus` |
| setScanningTasksStatus | POST | Update task status for specific companies |
| setScanningTasksStatusFromTo | POST | Bulk status transition (from → to) |
| uploadScanningTasksFromFile | POST | Upload companies via CSV to create tasks |
| deleteScanningTasksByCompanyId | POST | Delete tasks for specific companies |
| deleteScanningTasksByStatus | POST | Delete all tasks in a given status |
| deleteAllScanningTasks | POST | Delete all tasks of a type |
| fillScanningTasksForAllCompanies | POST | Populate tasks for all eligible companies |

```
Common params:
  taskName: IngesterTaskName (enum)
  taskStatus: IngesterTaskStatus (enum)
  companyIdsStr: String (comma-separated)
```

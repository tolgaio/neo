# Ashby API Endpoint Reference

## Table of Contents

- [job.list](#joblist)
- [job.info](#jobinfo)
- [candidate.search](#candidatesearch)
- [candidate.info](#candidateinfo)
- [candidate.listNotes](#candidatelistnotes)
- [candidate.createNote](#candidatecreatenote)
- [file.info](#fileinfo)
- [application.list](#applicationlist)
- [application.info](#applicationinfo)
- [application.listHistory](#applicationlisthistory)
- [applicationFeedback.list](#applicationfeedbacklist)
- [application.listCriteriaEvaluations](#applicationlistcriteriaevaluations)
- [Additional Endpoints](#additional-endpoints)

---

## job.list

**POST** `https://api.ashbyhq.com/job.list` | Permission: `jobsRead`

### Request

| Parameter | Type | Description |
|-----------|------|-------------|
| limit | number | Max items (default/max: 100) |
| cursor | string | Pagination cursor |
| createdAfter | int64 | Unix epoch ms filter |
| status | array | Filter by status (e.g. "Draft") |
| openedAfter | int64 | Jobs opened after timestamp |
| openedBefore | int64 | Jobs opened before timestamp |
| closedAfter | int64 | Jobs closed after timestamp |
| closedBefore | int64 | Jobs closed before timestamp |
| expand | array | Expand related data |

### Response

```json
{
  "success": true,
  "results": [{ "id": "uuid", "title": "string", "status": "string", ... }],
  "moreDataAvailable": false,
  "nextCursor": null
}
```

---

## job.info

**POST** `https://api.ashbyhq.com/job.info` | Permission: `jobsRead`

### Request

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | uuid | yes | Job ID |
| expand | array | no | Expand related data |

---

## candidate.search

**POST** `https://api.ashbyhq.com/candidate.search` | Permission: `candidatesRead`

### Request

| Parameter | Type | Description |
|-----------|------|-------------|
| name | string | Candidate name |
| email | string | Candidate email |

Multiple params are combined with AND. Max 100 results. Use `candidate.list` for larger sets.

---

## candidate.info

**POST** `https://api.ashbyhq.com/candidate.info` | Permission: `candidatesRead`

### Request

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | uuid | yes | Candidate ID |

### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| id | uuid | Candidate ID |
| firstName | string | First name |
| lastName | string | Last name |
| email | string | Primary email |
| alternateEmailAddresses | array | Other emails |
| phoneNumber | string | Phone |
| linkedInUrl | string | LinkedIn profile |
| githubUrl | string | GitHub profile |
| website | string | Personal website |
| city | string | City |
| region | string | Region/state |
| country | string | Country |
| tags | array | Tags (id, title) |
| fileHandles | array | Resume/document references |
| customFields | array | Custom field values |
| createdAt | datetime | Created timestamp |
| updatedAt | datetime | Last updated |

---

## file.info

**POST** `https://api.ashbyhq.com/file.info` | Permission: `candidatesRead`

Get a download URL for a candidate file (resume, cover letter, etc.).

### Request

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| fileHandle | string | yes | File handle from `candidate.info` (fileHandles) or `application.info` (resumeFileHandle) |

### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| url | string | Temporary download URL for the file |
| name | string | Original filename |
| handle | string | The file handle |

**Note:** Ashby-generated demo data may cause errors with this endpoint. Use real candidate data.

---

## candidate.listNotes

**POST** `https://api.ashbyhq.com/candidate.listNotes` | Permission: `candidatesRead`

### Request

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| candidateId | uuid | yes | Candidate ID |
| cursor | string | no | Pagination cursor |
| limit | number | no | Max items (default/max: 100) |

---

## candidate.createNote

**POST** `https://api.ashbyhq.com/candidate.createNote` | Permission: `candidatesWrite`

### Request

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| candidateId | uuid | yes | Candidate ID |
| note | string | yes | Note content (plain text or HTML) |
| sendNotifications | boolean | no | Notify subscribers (default: false) |
| isPrivate | boolean | no | Private note (default: false) |
| createdAt | datetime | no | Override creation timestamp |

**Supported HTML:** `<b>`, `<i>`, `<u>`, `<a>`, `<ul>`, `<ol>`, `<li>`, `<code>`, `<pre>`. Unsupported tags are stripped.

---

## application.list

**POST** `https://api.ashbyhq.com/application.list` | Permission: `candidatesRead`

### Request

| Parameter | Type | Description |
|-----------|------|-------------|
| limit | number | Max items (default/max: 100) |
| cursor | string | Pagination cursor |
| createdAfter | int64 | Unix epoch ms filter |
| status | string | Filter: `Active`, `Hired`, `Archived`, `Lead` |
| jobId | uuid | Filter by job |
| expand | array | Options: `openings` |

### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| id | uuid | Application ID |
| candidateId | uuid | Candidate ID |
| jobId | uuid | Job ID |
| status | string | Active/Hired/Archived/Lead |
| createdAt | datetime | Created timestamp |
| updatedAt | datetime | Last updated |
| applicationHistory | array | Stage progression |

Each history entry: `{ id, stageId, title, enteredStageAt, stageNumber }`

---

## application.info

**POST** `https://api.ashbyhq.com/application.info` | Permission: `candidatesRead`

### Request

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| applicationId | uuid | yes* | Application ID |
| submittedFormInstanceId | uuid | yes* | Alt: lookup by form instance |
| expand | array | no | `openings`, `applicationFormSubmissions`, `referrals` |

*One of applicationId or submittedFormInstanceId required.

### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| id | uuid | Application ID |
| candidateId | uuid | Candidate ID |
| jobId | uuid | Job ID |
| sourceId | uuid | Source ID |
| creditedToUserId | uuid | Credited user |
| status | string | Application status |
| resumeFileHandle | object | Resume file data |
| applicationHistory | array | Stage history |
| applicationFormSubmissions | array | Form responses (requires expand) |
| referrals | array | Referral info (requires expand) |
| openings | array | Job openings (requires expand) |

---

## application.listHistory

**POST** `https://api.ashbyhq.com/application.listHistory` | Permission: `candidatesRead`

### Request

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| applicationId | uuid | yes | Application ID |

---

## applicationFeedback.list

**POST** `https://api.ashbyhq.com/applicationFeedback.list` | Permission: `candidatesRead`

### Request

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| applicationId | uuid | yes | Application ID |
| cursor | string | no | Pagination cursor |
| limit | number | no | Max items (default/max: 100) |
| createdAfter | int64 | no | Unix epoch ms filter |

### Response Fields

Each feedback submission includes:

| Field | Type | Description |
|-------|------|-------------|
| id | uuid | Feedback ID |
| applicationId | uuid | Application ID |
| feedbackFormDefinitionId | uuid | Form definition ID |
| interviewId | uuid | Related interview (optional) |
| submittedAt | datetime | Submission timestamp |
| submittedByUser | object | User who submitted (id, firstName, lastName, email) |
| formDefinition | object | Form structure with sections and field definitions |
| submittedValues | object | Actual responses (text, scores, selections like "Strong Hire") |

Form field types: `ValueSelect`, `Score`, `RichText`

---

## application.listCriteriaEvaluations

**POST** `https://api.ashbyhq.com/application.listCriteriaEvaluations` | Permission: `candidatesRead`

Requires the AI Application Review feature.

### Request

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| applicationId | uuid | yes | Application ID |
| cursor | string | no | Pagination cursor |
| limit | number | no | Max items (default/max: 100) |

### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| id | uuid | Evaluation ID |
| criterion.title | string | What was evaluated |
| criterion.type | string | `ResumePrompt`, `DidAnswerApplicationFormQuestion`, `SimilarityToAiGeneratedAnswer` |
| criterion.prompt | string | The evaluation prompt |
| status | string | `Pending`, `Completed`, `Failed`, `Skipped` |
| outcome | string | `Meets` or `Does Not Meet` (nullable) |
| reasoning | string | AI's reasoning (nullable) |
| outcomeNumber | float | 0.0-1.0 score (nullable) |
| evaluatedAt | datetime | Completion timestamp (nullable) |
| skipReason | string | Reason if skipped (nullable) |

---

## Additional Endpoints

These may be useful for adjacent workflows:

| Endpoint | Permission | Description |
|----------|------------|-------------|
| `candidate.list` | candidatesRead | Paginated candidate list (for bulk operations) |
| `candidate.addTag` | candidatesWrite | Add tag to candidate |
| `application.changeStage` | candidatesWrite | Move application to different stage |
| `application.changeSource` | candidatesWrite | Update application source |
| `interviewSchedule.list` | interviewsRead | List interview schedules |
| `archiveReason.list` | organizationRead | List archive reasons |
| `apiKey.info` | - | Verify API key connectivity |

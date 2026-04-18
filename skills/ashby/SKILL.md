---
name: ashby
description: "Query and manage Ashby ATS resources (candidates, applications, jobs, feedback, notes) via the Ashby API. Use when the user asks about job applicants, candidate evaluation, application review, hiring pipeline, CV/resume analysis, interview feedback, or adding evaluation notes to candidates."
---

# Ashby ATS API

## Authentication

Basic Auth using `$ASHBY_API_TOKEN` as username, empty password:

```bash
AUTH="Authorization: Basic $(echo -n "$ASHBY_API_TOKEN:" | base64)"
```

**Required API key scopes:** Candidates (Read + Write), Jobs (Read)

## Base URL & Convention

```
https://api.ashbyhq.com
```

All endpoints are **POST** with `Content-Type: application/json` body (even reads).

## Workflows

### Browse applicants by job

1. List open jobs: `job.list`
2. List applications for a job: `application.list` with `jobId` and `status` filter
3. Get candidate details: `candidate.info` with candidate `id`
4. Get application details + form answers: `application.info` with `expand: ["applicationFormSubmissions"]`
5. Get existing feedback: `applicationFeedback.list` with `applicationId`
6. Get AI evaluations: `application.listCriteriaEvaluations` with `applicationId`
7. Add evaluation note: `candidate.createNote`

### Search specific candidates

1. Search: `candidate.search` with `name` or `email`
2. Get their applications: `application.list` (no jobId filter)
3. Continue from step 3 above

## Core Endpoints

### Jobs

```bash
# List all jobs (filter by status)
curl -s -X POST "https://api.ashbyhq.com/job.list" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"limit": 100}'

# Get job details
curl -s -X POST "https://api.ashbyhq.com/job.info" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"id": "JOB_ID"}'
```

### Candidates

```bash
# Search by name or email (max 100 results, AND logic for multiple params)
curl -s -X POST "https://api.ashbyhq.com/candidate.search" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"name": "Jane Doe"}'

# Get full candidate profile
curl -s -X POST "https://api.ashbyhq.com/candidate.info" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"id": "CANDIDATE_ID"}'

# List candidate notes
curl -s -X POST "https://api.ashbyhq.com/candidate.listNotes" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"candidateId": "CANDIDATE_ID"}'

# Add evaluation note (supports HTML: b, i, u, a, ul, ol, li, code, pre)
curl -s -X POST "https://api.ashbyhq.com/candidate.createNote" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"candidateId": "CANDIDATE_ID", "note": "Evaluation note text", "sendNotifications": false}'
```

### Files (Resumes)

```bash
# Get download URL for a file (use fileHandle from candidate.info or application.info)
curl -s -X POST "https://api.ashbyhq.com/file.info" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"fileHandle": "FILE_HANDLE_FROM_CANDIDATE_OR_APPLICATION"}'
```

To download a resume: get `fileHandles` from `candidate.info` or `resumeFileHandle` from `application.info`, then pass it to `file.info` to get the download URL.

### Applications

```bash
# List applications (filter by jobId, status: Active/Hired/Archived/Lead)
curl -s -X POST "https://api.ashbyhq.com/application.list" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"jobId": "JOB_ID", "status": "Active", "limit": 100}'

# Get application details with form submissions and referrals
curl -s -X POST "https://api.ashbyhq.com/application.info" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"applicationId": "APP_ID", "expand": ["applicationFormSubmissions", "referrals"]}'
```

### Feedback & Evaluations

```bash
# List interview scorecards/feedback for an application
curl -s -X POST "https://api.ashbyhq.com/applicationFeedback.list" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"applicationId": "APP_ID"}'

# Get AI-generated criteria evaluations (requires AI Review feature)
curl -s -X POST "https://api.ashbyhq.com/application.listCriteriaEvaluations" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"applicationId": "APP_ID"}'
```

## Pagination

Cursor-based. Check `moreDataAvailable` and use `nextCursor`:

```bash
# First page
curl -s -X POST "https://api.ashbyhq.com/application.list" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"jobId": "JOB_ID", "limit": 100}'

# Next page (use nextCursor from previous response)
curl -s -X POST "https://api.ashbyhq.com/application.list" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"jobId": "JOB_ID", "limit": 100, "cursor": "NEXT_CURSOR_VALUE"}'
```

## Response Format

All responses follow: `{"success": true, "results": ..., "moreDataAvailable": bool, "nextCursor": "..."}`.

For single-object endpoints (`.info`), `results` is an object. For list endpoints, `results` is an array.

Handle HTTP 429 with exponential backoff.

## Full Endpoint Reference

See [references/endpoints.md](references/endpoints.md) for complete parameter and response schemas.

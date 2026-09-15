# Work Task Tracker

`Work-Tasks.xlsx` - a task tracker for a workplace with no ticketing system
(no ServiceNow-equivalent). Tasks get assigned informally, so this is
somewhere to log status, priority, and due dates.

## Why Excel, not an app

Plain Excel on purpose, instead of a to-do/project-tracking app or SaaS
tool: a workplace can restrict or block installing/accessing tools like
that, but a spreadsheet is basically always available (already installed,
or opens fine in whatever's on hand) and works completely offline - no
account, sign-up, or IT approval needed just to track my own tasks.

## Columns

| Column | Meaning |
|---|---|
| ID | Sequential number |
| Task | Short description |
| Description | Longer detail on the task |
| Assigned By | Who assigned it (role/relationship, not necessarily a full name) |
| Date Assigned | When it landed on your plate |
| Priority | High / Medium / Low (dropdown) |
| Status | New / In-Progress / Hold / Completed (dropdown, color-coded) |
| Due Date | If one exists |
| Notes | Anything relevant - blockers, context, links |
| Date Completed | Filled in when moved to Completed |

## Dashboard

A `Dashboard` sheet holds a Status breakdown and a Priority breakdown (COUNTIF
formulas against the `Tasks` sheet) plus a bar chart for each. Both update
automatically as rows are added/edited on `Tasks`.

## Workflow

1. New task assigned - add a row, fill ID/Task/Description/Assigned By/Date Assigned/Priority, Status = New.
2. Update Status as it moves (In-Progress / Hold), add Notes as needed.
3. Mark Completed and fill Date Completed when finished.
4. Periodically move old Completed rows out (e.g. to a dated archive tab, or delete) so the active view stays short.

## Keeping this safe to be public

This repo is public, so anything committed here is public and stays in git
history even if later edited out. Keep task descriptions generic (the kind
of work, not real confidential system/client/project names) - same rule as
any other public repo. No tickets, emails, credentials, or verbatim internal
text pasted in.

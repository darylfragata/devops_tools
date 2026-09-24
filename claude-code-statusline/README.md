# Claude Code Status Line

A status line for [Claude Code](https://claude.com/claude-code) that shows usage,
limits, context, session time, and git branch under the prompt, so I don't have
to run `/usage` or guess how close I am to a limit.

```
Sonnet 5 │ ⏱ 47m │ ctx ████████░░ 88% ⚠ /compact │ sess $1.20 │ today $3.50 │ month $37.10 │ 5h ██████░░░░ 63% ↻2h13m │ 7d █████████░ 91% ↻2d5h
dfOS main*
```

(Example output. Numbers are illustrative.)

## Where it applies

- **Checked on:** an individual account, where every segment showed and the
  fields below were present in the real payload.
- **Enterprise / usage-based billing:** untested. The `5h` / `7d` bars may not
  show. The other segments should still work, and `sess $` is an estimate, not
  your spend against an org limit. Admins may also manage the `statusLine`
  setting; I haven't checked.

## What it shows

**Line 1**

| Segment | Meaning |
|---|---|
| `Sonnet 5` | Current model |
| `⏱ 47m` | Session duration |
| `ctx ████ 42%` | Context window used. Turns yellow at 70%, red at 90%, adds `⚠ /compact` at 85%+ |
| `sess $1.20` | Cost of **this session only**, estimated at API list price |
| `today` / `month` | Running totals across sessions on this machine (see below) |
| `5h` / `7d` | Plan usage limits with `↻` time until reset |

**Line 2**: folder name and git branch (`*` = uncommitted changes).

Any segment Claude Code doesn't report is skipped.

## Does it use tokens?

No. Claude Code runs the script locally and draws its output in the terminal.
The output is never added to the conversation, so it doesn't count toward
usage or the context window. It costs a little local CPU (a few `jq` calls and
`git status`) and nothing else. (This is how the feature is designed to work;
I didn't measure usage with and without it.)

It refreshes when the session updates, not on a fixed clock, so a live-ticking
seconds timer isn't possible. That's why the timer is in minutes.

## Benefits

- See the 5h / 7d limits and when they reset without leaving the prompt.
- Get a warning before context fills up, so `/compact` happens on purpose.
- Spot the wrong repo or branch at a glance when jumping between projects.
- Rough daily/monthly spend tracking with no extra tooling.

## Install

Requires `bash`, `jq`, and `git`.

```bash
mkdir -p ~/.claude
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Then add this to `~/.claude/settings.json` (user-level, applies to every project):

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

Start a new Claude Code session (or restart) to see it.

Test it without Claude Code by piping sample JSON in:

```bash
echo '{"model":{"display_name":"Sonnet 5"},"context_window":{"used_percentage":42}}' | ~/.claude/statusline.sh
```

## Spend tracking (`today` / `month`)

Each refresh saves the session's latest cost to `~/.claude/spend.json`, keyed by
`session_id`, then sums by day and month. Entries older than 62 days are pruned.

Limits, so the numbers aren't over-trusted:

- **Estimate only.** It's list-price cost, not necessarily what you're billed.
- **This machine only.** Usage on other machines or the web isn't counted.
- **No history.** It only counts from when it was turned on.
- A session that crosses midnight counts toward the day it was last updated.
- `sess` is not a spend limit. If your org has a spend cap, that's a total across
  sessions and the status line can't see it. Use the admin/usage page.

## What Claude Code sends

The script reads these fields from the JSON Claude Code passes on stdin (checked
against a real payload from Claude Code v2.1.281):

`model.display_name`, `workspace.current_dir`, `session_id`,
`cost.total_cost_usd`, `cost.total_duration_ms`, `context_window.used_percentage`,
`rate_limits.five_hour` and `rate_limits.seven_day` (`used_percentage`,
`resets_at` as a Unix timestamp).

There is no field for credits, remaining balance, or a spend limit, so the
status line can't show those. The `rate_limits` fields appeared on the individual
account I checked; I haven't confirmed they appear on every plan type.

To see exactly what your version sends, temporarily add this after the
`input=$(cat)` line, send a message, then read the file and remove the line:

```bash
printf "%s" "$input" > ~/.claude/statusline-payload.json
```

The payload includes your session ID and file paths, so keep it local.

## Not verified

- How the two-line layout looks across different terminals and widths.
- Whether `5h` / `7d` show on every plan type (untested on usage-based/enterprise).
- Very wide lines get cut off on the right by the terminal.

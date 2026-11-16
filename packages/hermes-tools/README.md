# Hermes personal tools

The NixOS [personal tools module](../../modules/features/services/hermes/_personal.nix)
mounts the tools, installs their Python dependencies, and supplies the default
cron jobs and encrypted backup timer. The host feature settings supply the mail
accounts and the backup destination.

Hermes applies the Nix-generated `/etc/hermes/config.yaml` over its writable
`/opt/data/config.yaml`. Change managed settings in the host's `services/hermes`
feature. Hermes can save settings whose keys are left to the profile.

This package supplies the campus and mail integrations:

- BIT SSO login with an SMS challenge that can span MCP tool calls.
- Read-only IMAP, old Lexue calendars, Eclass assignments and materials, and AITA deadlines.

Courses use the
[Yanhekit](https://github.com/bitoolkit/yanhekit) CLI. Scheduling,
messages, backups and conversation state use Hermes native commands.

The campus tools prepare and validate Yanhekt cookies before course commands.
The deployment patches Yanhekit's interactive login fallback to report an
authentication requirement instead of starting a WebUI; SMS verification stays
in the conversation through the existing MCP tools.

The main agent owns conversation, persona and delegation. Child agents perform
the work: fetching and analyzing mail, using campus tools, querying courses and
writing materials. A child executes its assignment directly and may split it
when useful; it does not have to delegate again. The main agent receives results,
asks Ray for any missing information and communicates what matters.

`personal-assistant/SKILL.md` describes that division. Its mail and school
references contain only the context needed for those tasks; upstream Yanhekit
skills supply the course tooling. Course selection comes from Ray's request and
live search, with no preset course or required processing pipeline.

Interactive delegation runs in the background. The main agent ends its turn
after dispatch and receives completion through Hermes, without polling or
repeated progress messages. Cron delegation waits for the child result. SMS
codes pass from Ray through the main agent to a child for submission; the main
agent does not perform campus login itself.

Nix builds a wheel and bundles it with the locked runtime requirements, skills,
and monitor scripts. The Hermes container syncs that bundle into its Python
environment on startup.

On first startup, Hermes gets default mail, Lexue, deadline and course jobs if the persistent
profile has no `cron/jobs.json`. Hermes owns the jobs after that. Use `hermes cron`
to change their schedules, pause them, or remove them.
Existing profiles get the added deadline and course jobs once through
`hermes cron create`. After registration, Hermes owns their lifecycle as well.

Notifications use the Telegram home chat set with `/sethome`.
The `message-reactions` SDK plugin lets Hermes react to the current Telegram
message without sending text. Add `message-reactions` to `plugins.enabled` and grant
`plugins.entries.message-reactions.allow_platform_actions`. Set
`platforms.<platform>.channel_overrides.<chat_id>.allow_silence` for conversations
where a completed `[SILENT]` turn should produce no text. This permission does not
hide failed or interrupted replies.

The mail monitor wakes Hermes when unread message IDs change. The child agent
reviews new messages, and the coordinator sends one summary when Ray needs to
act through the native message tool. A separate script-only job checks old Lexue,
Eclass and AITA every 15 minutes and returns reminders within 24 hours and
2 hours of a deadline. Hermes delivers these without a model. The script checks
the prior execution's native delivery result before marking a reminder sent.
Failed deliveries can be retried while the deadline is in the future. Completed,
hidden, expired, and opening events are skipped. Unknown submission status is
stated in the message. Reminder state lives in
`.local/state/hermes-personal/reminders.sqlite3` under the profile.

The hourly course monitor checks new Eclass materials and the latest term's
Yanhekt replays. Workers prefer new Eclass files, match missing recordings to
Yanhekt by course, teacher, term and lecture date, and save outputs under
`HERMES_COURSES_DIR`. Set `personal.coursesDirectory` to mount the host's NAS
directory at `/courses` for recordings, slides, transcripts and notes.

AITA deadlines and replays use the latest enrolled term. Its structured homework
deadlines are separate from Eclass; recording availability is not a deadline.


# Hermes personal tools

This package contains only the two integrations Hermes cannot provide itself:

- BIT SSO login with an SMS challenge that can span MCP tool calls.
- Read-only IMAP and Lexue calendar reads.

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
environment on startup. `bootstrap.py` imports credentials from the old controller
once, removes retired jobs, and registers the mail and Lexue monitors.


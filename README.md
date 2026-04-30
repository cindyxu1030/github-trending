# GitHub Trending Daily Scanner

A small automation that uses [Claude Code](https://docs.claude.com/claude-code) to find 3 hot GitHub repos each day and email you a curated digest. It deduplicates against repos already sent and personalizes ranking around your stated interests.

## What it does

Each run:

1. Reads a history file of repos already sent to avoid duplicates.
2. Queries the GitHub Search API for high-momentum repos (recently pushed, recently created with star surges).
3. Cross-references with `github.com/trending` and a web search for the current month.
4. Picks 3 standouts not yet sent, weighted toward your `INTERESTS` config.
5. Writes a markdown report under `data/reports/`.
6. Appends the picks to `data/sent_repos.md`.
7. Emails the report via your own send-email script.

## Requirements

- macOS or Linux
- [Claude Code CLI](https://docs.claude.com/claude-code) installed and authenticated
- A script you control that sends email (any language) accepting the flags `--to`, `--subject`, `--body-file`

The repo intentionally does **not** ship an emailer — bring your own SMTP/Resend/SES wrapper to keep credentials out of the project.

## Setup

```bash
git clone <your-fork-url> github-trending
cd github-trending
cp .env.example .env
# edit .env with your email + path to your send-email script
chmod +x scripts/run_daily.sh
```

Test it:

```bash
./scripts/run_daily.sh
tail -f logs/github-trending.log
```

## Configuration

All config lives in `.env` (loaded by the script). See `.env.example` for the full list. The two required values:

| Variable | Description |
|---|---|
| `RECIPIENT_EMAIL` | Where the daily digest is sent |
| `SEND_EMAIL_SCRIPT` | Absolute path to your email sender. Must accept `--to`, `--subject`, `--body-file` |

Optional:

| Variable | Default | Notes |
|---|---|---|
| `INTERESTS` | `AI/ML, developer tools, frontend, automation` | Comma-separated topics that bias ranking |
| `MODEL` | `claude-sonnet-4-6` | Any Claude Code-compatible model ID |
| `DATA_DIR` / `REPORTS_DIR` / `SENT_REPOS_FILE` / `LOG_DIR` | inside repo | Override if you want output elsewhere |

## Scheduling

### macOS LaunchAgent (recommended)

Create `~/Library/LaunchAgents/com.user.github-trending.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.github-trending</string>
    <key>ProgramArguments</key>
    <array>
        <string>/absolute/path/to/github-trending/scripts/run_daily.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key><integer>9</integer>
        <key>Minute</key><integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/github-trending.out</string>
    <key>StandardErrorPath</key>
    <string>/tmp/github-trending.err</string>
</dict>
</plist>
```

Load it:

```bash
launchctl load ~/Library/LaunchAgents/com.user.github-trending.plist
```

### Linux cron

```cron
0 9 * * * /absolute/path/to/github-trending/scripts/run_daily.sh
```

## Output

- `data/reports/report_YYYY-MM-DD.md` — the daily digest, one file per run.
- `data/sent_repos.md` — append-only history used for dedup.
- `logs/github-trending.log` — run log.

These directories are gitignored — they hold your personal scan output.

## License

MIT — see [LICENSE](LICENSE).

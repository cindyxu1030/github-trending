#!/usr/bin/env bash
# GitHub Trending Daily Scanner
# Uses Claude Code CLI to find 3 hot GitHub repos and email a digest.
#
# Setup:
#   1. Install Claude Code CLI: https://docs.claude.com/claude-code
#   2. Copy .env.example to .env and fill in values
#   3. (Optional) Schedule via cron or LaunchAgent — see README

set -euo pipefail

# Resolve repo root (one level up from scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load .env if present
ENV_FILE="${ENV_FILE:-$REPO_DIR/.env}"
if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
fi

# Required config
: "${RECIPIENT_EMAIL:?RECIPIENT_EMAIL not set — copy .env.example to .env}"
: "${SEND_EMAIL_SCRIPT:?SEND_EMAIL_SCRIPT not set — path to your email-sending script}"

# Optional config
INTERESTS="${INTERESTS:-AI/ML, developer tools, frontend, automation}"
MODEL="${MODEL:-claude-sonnet-4-6}"
DATA_DIR="${DATA_DIR:-$REPO_DIR/data}"
REPORTS_DIR="${REPORTS_DIR:-$DATA_DIR/reports}"
SENT_REPOS_FILE="${SENT_REPOS_FILE:-$DATA_DIR/sent_repos.md}"
LOG_DIR="${LOG_DIR:-$REPO_DIR/logs}"

mkdir -p "$REPORTS_DIR" "$LOG_DIR"
[ -f "$SENT_REPOS_FILE" ] || cat > "$SENT_REPOS_FILE" <<'EOF'
# GitHub Trending — Previously Sent Repos
# Format: repo_full_name | date_sent | stars_at_time
EOF

LOG_FILE="$LOG_DIR/github-trending.log"
TODAY="$(date '+%Y-%m-%d')"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] GitHub Trending scan starting..." >> "$LOG_FILE"

claude \
    --model "$MODEL" \
    -p "You are the GitHub Trending Daily Scanner. Today is $TODAY.

## Task
Find the 3 hottest GitHub repositories right now and email the report to $RECIPIENT_EMAIL.

## Step 1: Check History
Read $SENT_REPOS_FILE to see which repos have already been sent. Do NOT include any repo that appears in that file.

## Step 2: Find Trending Repos
Use multiple methods:

1. Use curl to hit the GitHub Search API (public, no auth needed):
   curl -s 'https://api.github.com/search/repositories?q=stars:>5000+pushed:>$(date -v-7d '+%Y-%m-%d')&sort=stars&order=desc&per_page=30'

2. Find new repos that exploded recently:
   curl -s 'https://api.github.com/search/repositories?q=created:>$(date -v-30d '+%Y-%m-%d')+stars:>1000&sort=stars&order=desc&per_page=20'

3. Use WebSearch to search for 'GitHub trending repos this week $(date '+%B %Y')' and cross-reference.

4. Use WebFetch on https://github.com/trending to see what GitHub highlights.

## Step 3: Select Top 3
Pick the 3 most interesting repos NOT already in the sent_repos file. Prioritize:
- Repos with explosive recent growth (new and skyrocketing, or established with a major surge)
- Repos relevant to these interests: $INTERESTS
- Genuinely useful developer tools gaining momentum

## Step 4: Write the Report
For each repo:
- Repo name with full GitHub URL
- Star count and language
- Summary paragraph (3-5 sentences): What is it? Why is it popular right now? What's new? Why do people follow it?

## Step 5: Beneficial Expansion
If any repo is particularly relevant to the configured interests ($INTERESTS), write an expanded 'Why This Matters' section explaining specifically how it could be useful.

## Step 6: Update History
Append the 3 repo names to $SENT_REPOS_FILE with today's date and star count.

## Step 7: Save Report
Write the full report to $REPORTS_DIR/report_$TODAY.md

## Step 8: Send Email
Compose the email body and write it to /tmp/github_trending_email.txt, then run:
$SEND_EMAIL_SCRIPT --to '$RECIPIENT_EMAIL' --subject 'GitHub Trending — $TODAY' --body-file /tmp/github_trending_email.txt

The email body should be clean and readable plain text with the full report.

## Rules
- Never fabricate star counts or repo details — verify via the API
- Include real, working GitHub URLs
- Focus on what's genuinely trending NOW, not all-time popular repos everyone already knows
- Keep summaries insightful — explain WHY it's trending, not just WHAT it does
- Do NOT include repos already in the sent_repos file" \
    >> "$LOG_FILE" 2>&1

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] GitHub Trending scan completed successfully." >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] GitHub Trending scan FAILED (exit $EXIT_CODE)." >> "$LOG_FILE"
fi

exit $EXIT_CODE

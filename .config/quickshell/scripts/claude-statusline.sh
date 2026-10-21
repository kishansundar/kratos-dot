#!/bin/sh
# Claude Code status line (settings.json: statusLine.command), and the shell's source for what only Claude Code
# knows: the model, the context window, the session's cost estimate and, for Pro/Max plans, the five-hour and weekly
# usage limits. Claude Code passes these as documented JSON on stdin after each assistant message.
#
# Several sessions run at once, each with its own context and cost, so each report is kept under its session_id
# (sessions/<id>.json); status.json holds the newest report of any session, for the plan limits (which are
# account-wide). Files are private to the user. Read-only towards Claude Code: nothing is sent anywhere, and no
# conversation text is in this JSON.
umask 077
input=$(cat)
dir=${XDG_CACHE_HOME:-$HOME/.cache}/swiss-desktop/claude
mkdir -p "$dir/sessions"
field() { printf '%s' "$input" | sed -n "s/.*$1.*/\\1/p" | head -n 1; }

now=$(date +%s)
report=$(printf '{"written_at":%s,"status":%s}' "$now" "$input")
# Write through a rename: the shell watches these files.
printf '%s\n' "$report" > "$dir/status.json.tmp" && mv -f "$dir/status.json.tmp" "$dir/status.json"
id=$(field '"session_id":"\([A-Za-z0-9-]*\)"')
if [ -n "$id" ]; then
    printf '%s\n' "$report" > "$dir/sessions/$id.json.tmp" && mv -f "$dir/sessions/$id.json.tmp" "$dir/sessions/$id.json"
fi
# Forget sessions not heard from for a day.
find "$dir/sessions" -name '*.json' -mmin +1440 -delete 2>/dev/null

# The line Claude Code shows: model, context used, five-hour limit (each only when present).
model=$(field '"display_name":"\([^"]*\)"')
# Context used, from the token counts (they come before the nested current_usage object, so a flat match is safe).
used=$(field '"context_window":{"total_input_tokens":\([0-9]*\)')
size=$(field '"context_window_size":\([0-9]*\)')
context=""
[ -n "$used" ] && [ -n "$size" ] && [ "$size" -gt 0 ] && context=$((used * 100 / size))
five=$(field '"five_hour":{"used_percentage":\([0-9.]*\)')
line=${model:-Claude}
[ -n "$context" ] && line="$line · context ${context%.*}%"
[ -n "$five" ] && line="$line · 5h ${five%.*}%"
printf '%s\n' "$line"

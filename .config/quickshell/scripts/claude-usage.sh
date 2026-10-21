#!/bin/sh
# Today's Claude Code token usage, from the local session logs (~/.claude/projects/*/*.jsonl), read-only.
# Prints one JSON object. The log format is internal to Claude Code and may change between versions, so the
# Claude popover labels these numbers as a local estimate, and this script reports ok:false rather than guessing.
#
# Each API response is logged once per content block with the same usage, so responses are counted once,
# by message id. Only files changed today are read. No message text leaves this script. A subagent's log
# (<session>/subagents/*.jsonl) counts toward its session: its tokens are real use, but it is not a session of its own.
root=${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects
now=$(date +%s)
# Active sessions: main session logs written in the last 5 minutes (one session runs several processes,
# so a process count would mislead).
active=$(find "$root" -mindepth 2 -maxdepth 2 -name '*.jsonl' -mmin -5 2>/dev/null | wc -l)

if [ ! -d "$root" ]; then
    printf '{"ok":false,"reason":"no session logs in %s","active":%s,"computed_at":%s}\n' "$root" "$active" "$now"
    exit 0
fi

# Local midnight, written in UTC as the logs' timestamps are (with -u alone, date reads "today 00:00" as UTC too).
since=$(date -u -d "@$(date -d 'today 00:00' +%s)" +%Y-%m-%dT%H:%M:%S)
current=$(ls -t "$root"/*/*.jsonl 2>/dev/null | head -n 1)
files=$(find "$root" -name '*.jsonl' -newermt 'today 00:00' 2>/dev/null)

if [ -z "$files" ]; then
    printf '{"ok":true,"day":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0,"responses":0,"sessions":0},"current":null,"active":%s,"computed_at":%s}\n' "$active" "$now"
    exit 0
fi

# shellcheck disable=SC2086
grep -H '"type":"assistant"' $files 2>/dev/null | awk -v since="$since" -v current="$current" -v active="$active" -v now="$now" '
function num(key,   m) { return match($0, "\"" key "\":[0-9]+") ? substr($0, RSTART + length(key) + 3, RLENGTH - length(key) - 3) + 0 : 0 }
function str(key,   m) { return match($0, "\"" key "\":\"[^\"]*\"") ? substr($0, RSTART + length(key) + 4, RLENGTH - length(key) - 5) : "" }
{
    file = substr($0, 1, index($0, ":") - 1)
    if (!match($0, /"id":"msg_[A-Za-z0-9_]+"/)) next
    id = substr($0, RSTART + 6, RLENGTH - 7)
    if (seen[id]++) next
    if (!match($0, /"usage":\{/)) next
    i = num("input_tokens"); o = num("output_tokens"); cr = num("cache_read_input_tokens"); cw = num("cache_creation_input_tokens")
    ts = str("timestamp"); model = str("model")
    s = file; sub(/\/subagents\/[^\/]*$/, ".jsonl", s)
    if (ts >= since) { di += i; do_ += o; dcr += cr; dcw += cw; dn++; sess[s] = 1 }
    if (file == current) { ci += i; co += o; ccr += cr; ccw += cw; cn++; cmodel = model; cts = ts; ctx = i + cr + cw }
    ok = 1
}
END {
    ns = 0; for (f in sess) ns++
    printf "{\"ok\":%s,", ok ? "true" : "false"
    printf "\"day\":{\"input\":%d,\"output\":%d,\"cacheRead\":%d,\"cacheWrite\":%d,\"responses\":%d,\"sessions\":%d},", di, do_, dcr, dcw, dn, ns
    if (cn > 0) {
        n = split(current, parts, "/"); sid = parts[n]; sub(/\.jsonl$/, "", sid)
        printf "\"current\":{\"session\":\"%s\",\"model\":\"%s\",\"input\":%d,\"output\":%d,\"cacheRead\":%d,\"cacheWrite\":%d,\"responses\":%d,\"context\":%d,\"last\":\"%s\"},", substr(sid, 1, 8), cmodel, ci, co, ccr, ccw, cn, ctx, cts
    } else printf "\"current\":null,"
    printf "\"active\":%d,\"computed_at\":%d}\n", active, now
}'

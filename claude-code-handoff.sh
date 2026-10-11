#!/usr/bin/env bash
# Export a Claude Code session as a Markdown handoff (user/assistant text only).
#
# Usage: ./claude-code-handoff.sh [-t] [-o out.md] [session-id] [project-path]
#   session-id    full session id or any unique part of it; omit for the newest session
#   project-path  directory Claude Code ran in (e.g. /mnt/c/github/lexara); narrows the
#                 search, and is the current directory when no session id is given
#   -o out.md     output file, "-" for stdout (default: ~/handoff.md)
#   -t            also list tool calls, one line each
#
# Transcripts are read from ${CLAUDE_CONFIG_DIR:-~/.claude}/projects/<project-path with
# every non-alphanumeric character turned into ->/<session-id>.jsonl (and, under WSL,
# from the Windows side's C:\Users\*\.claude\projects too).
set -euo pipefail

OUT="$HOME/handoff.md"
TOOLS=false
while getopts "o:th" opt; do
  case $opt in
    o) OUT=$OPTARG ;;
    t) TOOLS=true ;;
    *) sed -n '2,13p' "$0"; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
ID=${1:-}
PROJ=${2:-}

ROOTS=("${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects")
if [ -z "${CLAUDE_CONFIG_DIR:-}" ]; then
  for d in /mnt/*/Users/*/.claude/projects; do [ -d "$d" ] && ROOTS+=("$d"); done
fi

# find_newest DIR... -> newest *ID*.jsonl session file under DIRs (subagent transcripts excluded)
find_newest() {
  local f newest=""
  while IFS= read -r -d '' f; do
    { [ -z "$newest" ] || [ "$f" -nt "$newest" ]; } && newest=$f
  done < <(find "$@" -name "*${ID}*.jsonl" -not -path "*/subagents/*" -print0 2>/dev/null)
  printf '%s' "$newest"
}

[ -z "$ID" ] && [ -z "$PROJ" ] && PROJ=.
F=""
if [ -n "$PROJ" ]; then
  P=$(cd "$PROJ" 2>/dev/null && pwd -P || printf '%s' "${PROJ%/}")
  PDIRS=()
  for r in "${ROOTS[@]}"; do PDIRS+=("$r/$(printf '%s' "$P" | sed 's/[^a-zA-Z0-9]/-/g')"); done
  F=$(find_newest "${PDIRS[@]}")
  [ -z "$F" ] && echo "No session found for project $P, searching all projects" >&2
fi
[ -z "$F" ] && F=$(find_newest "${ROOTS[@]}")
[ -z "$F" ] && { echo "No Claude Code session matching '${ID}' under ${ROOTS[*]}" >&2; exit 1; }

echo "$F" >&2
[ "$OUT" = - ] || exec > "$OUT"

jq -n -r --argjson tools "$TOOLS" '
  def skip: test("^\\s*<[a-z][a-z0-9_-]*>") or startswith("[Request interrupted");
  def arg: [.file_path, .command, .pattern, .url, .query, .description]
    | map(select(type == "string" and . != "")) | (.[0] // "") | split("\n")[0] | .[0:200];
  [ inputs
    # messages typed while Claude was working are stored as queued_command attachments
    | if .type == "attachment" and .attachment.type == "queued_command"
        and (.attachment.commandMode // "prompt") == "prompt"
      then . + {type: "user", message: {content: .attachment.prompt}} else . end
    | select((.type == "user" or .type == "assistant")
        and (.isSidechain | not) and (.isMeta | not) and (.isCompactSummary | not)
        and (.isApiErrorMessage | not) and .message.model != "<synthetic>")
    | .type as $role
    | [ .message.content | if type == "string" then {type: "text", text: .} else .[] end
        | if .type == "text" then (.text | select(. != "" and (skip | not)))
          elif .type == "image" or .type == "document" then "[\(.type)]"
          elif .type == "tool_use" and $tools then "> \(.name): \(.input | arg)"
          else empty end ]
    | select(length > 0)
    | {role: $role, text: join("\n\n")} ]
  | reduce .[] as $m ([]; if length > 0 and .[-1].role == $m.role
      then .[-1].text += "\n\n" + $m.text else . + [$m] end)
  | .[] | "### \(.role | ascii_upcase)\n\(.text)\n"' "$F"

[ "$OUT" = - ] || echo "-> $OUT" >&2

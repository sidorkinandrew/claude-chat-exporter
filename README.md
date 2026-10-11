# claude-chat-exported

Usage: 

.\export-chat.ps1 <conversation_id>

Make sure to set both environment vars as below - 
$env:CLAUDE_ORG_ID = "your-org-uuid"
$env:CLAUDE_SESSION_KEY = "your-session-key"

Usage:

.\claude-project-chat-exporter.ps1 -ProjectId <<your-project-id>>

It will:
  1. Fetch the project name and create a folder named after it
  2. Paginate through all conversations
  3. Export each chat as <chat name>.json inside that folder
  4. Print the project name and each chat name as it goes

## Claude Code session handoff

`claude-code-handoff.sh` (bash/WSL/macOS, needs `jq`) and `claude-code-handoff.ps1` (PowerShell 5.1 or 7)
turn a local Claude Code session transcript into a Markdown handoff for another agent: only what you
typed and what Claude replied, as `### USER` / `### ASSISTANT` sections. Tool calls and results, thinking,
system reminders, slash-command output and subagent chatter are left out.

    ./claude-code-handoff.sh aeef28a3-2e3a-4af2-9c7e-371bf9a701c7                  # find the session anywhere
    ./claude-code-handoff.sh aeef28a3 /mnt/c/github/lexara                         # id prefix + project path
    ./claude-code-handoff.sh                                                       # newest session for the current dir
    ./claude-code-handoff.sh -t -o ./handoff.md aeef28a3                           # include one line per tool call

    .\claude-code-handoff.ps1 aeef28a3-2e3a-4af2-9c7e-371bf9a701c7
    .\claude-code-handoff.ps1 aeef28a3 C:\github\lexara -Out .\handoff.md -Tools

Output goes to `~/handoff.md` by default (`-o -` / `-Out -` prints to stdout).

Claude Code keeps transcripts in `~/.claude/projects/<project path with non-alphanumerics replaced by ->/<session-id>.jsonl`
(`/mnt/c/github/lexara` becomes `-mnt-c-github-lexara`, `C:\github\lexara` becomes `C--github-lexara`).
Set `CLAUDE_CONFIG_DIR` if you use a non-default config dir. Under WSL the bash script also looks in
`C:\Users\*\.claude\projects`, so sessions from native Windows Claude Code are found too.
The session id is shown by `/status`, and `claude --resume` lists past sessions.

If Windows blocks the script, run it as `powershell -ExecutionPolicy Bypass -File .\claude-code-handoff.ps1 ...`.

# Usage: .\export-chat.ps1 <conversation_id>
# Set both environment vars as below - 
# $env:CLAUDE_ORG_ID = "your-org-uuid"
# $env:CLAUDE_SESSION_KEY = "your-session-key"

curl.exe -s "https://claude.ai/api/organizations/$env:CLAUDE_ORG_ID/chat_conversations/$($args[0])?rendering=messages" -H "Cookie: sessionKey=$env:CLAUDE_SESSION_KEY"

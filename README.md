# claude-chat-exported

Usage: .\export-chat.ps1 <conversation_id>
Set both environment vars as below - 
$env:CLAUDE_ORG_ID = "your-org-uuid"
$env:CLAUDE_SESSION_KEY = "your-session-key"

Usage:
.\claude-project-chat-exporter.ps1 -ProjectId <<your-project-id>>

It will:
  1. Fetch the project name and create a folder named after it
  2. Paginate through all conversations
  3. Export each chat as <chat name>.json inside that folder
  4. Print the project name and each chat name as it goes

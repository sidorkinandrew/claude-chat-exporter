#Usage:
#.\claude-project-chat-exporter.ps1 -ProjectId <<your-project-id>>
#
#It will:
#  1. Fetch the project name and create a folder named after it
#  2. Paginate through all conversations
#  3. Export each chat as <chat name>.json inside that folder
#  4. Print the project name and each chat name as it goes

param([Parameter(Mandatory)][string]$ProjectId)

$org = $env:CLAUDE_ORG_ID
$key = $env:CLAUDE_SESSION_KEY

# Get project name
$proj = curl.exe -s "https://claude.ai/api/organizations/$org/projects/$ProjectId" -H "cookie: sessionKey=$key" -H "accept: application/json" | ConvertFrom-Json
$projName = $proj.name -replace '[\\/:*?"<>|]', '_'
$outDir = $projName
if (!(Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

Write-Output "Project: $($proj.name)"

# Paginate conversations
$offset = 0
$limit = 100
do {
  $json = curl.exe -s "https://claude.ai/api/organizations/$org/projects/$ProjectId/conversations_v2?limit=$limit&offset=$offset" -H "cookie: sessionKey=$key" -H "accept: application/json" | ConvertFrom-Json
  foreach ($c in $json.data) {
      $safeName = $c.name -replace '[\\/:*?"<>|]', '_'
      $filename = "$outDir\$safeName.json"
      Write-Output "  $($c.name)"
      curl.exe -s "https://claude.ai/api/organizations/$org/chat_conversations/$($c.uuid)?rendering=messages" -H "cookie: sessionKey=$key" -o $filename
  }
  $count = ($json | Measure-Object).Count
  $offset += $limit
} while ($count -eq $limit)

param([Parameter(Mandatory)][string]$ProjectId)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$org = $env:CLAUDE_ORG_ID
$key = $env:CLAUDE_SESSION_KEY
$tmp = [System.IO.Path]::GetTempFileName()

function Invoke-CurlUtf8($url) {
    curl.exe -s $url -H "cookie: sessionKey=$key" -H "accept: application/json" -o $tmp
    [System.IO.File]::ReadAllText($tmp, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
}

# Get project name
$proj = Invoke-CurlUtf8 "https://claude.ai/api/organizations/$org/projects/$ProjectId"
$projName = $proj.name -replace '[\\/:*?"<>|]', '_'
$outDir = $projName
if (!(Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

Write-Output "Project: $($proj.name)"

# Paginate conversations
$offset = 0
$chatCount = 0
$limit = 100
do {
    $json = Invoke-CurlUtf8 "https://claude.ai/api/organizations/$org/projects/$ProjectId/conversations_v2?limit=$limit&offset=$offset"
    foreach ($c in $json.data) {
        $safeName = $c.name -replace '[\\/:*?"<>|]', '_'
        $filename = "$outDir\$safeName.json"
        Write-Output "  $($c.name)"
        curl.exe -s "https://claude.ai/api/organizations/$org/chat_conversations/$($c.uuid)?rendering=messages" -H "cookie: sessionKey=$key" -o $filename
        $chatCount += 1
    }
    $count = ($json | Measure-Object).Count
    $offset += $limit
} while ($count -eq $limit)

Write-Output "$($chatCount) chats were exported to $($proj.name) folder"


Remove-Item $tmp -ErrorAction SilentlyContinue

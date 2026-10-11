<#
.SYNOPSIS
  Export a Claude Code session as a Markdown handoff (user/assistant text only).

.DESCRIPTION
  Transcripts are read from $env:CLAUDE_CONFIG_DIR (default ~\.claude)\projects\<project
  path with every non-alphanumeric character turned into ->\<session-id>.jsonl.

.EXAMPLE
  .\claude-code-handoff.ps1 aeef28a3-2e3a-4af2-9c7e-371bf9a701c7
.EXAMPLE
  .\claude-code-handoff.ps1 aeef28a3 C:\github\lexara -Out .\handoff.md -Tools
.EXAMPLE
  .\claude-code-handoff.ps1          # newest session for the current directory
#>
param(
    # Full session id or any unique part of it; omit for the newest session
    [string]$SessionId,
    # Directory Claude Code ran in; narrows the search, and is the current directory when no session id is given
    [string]$ProjectPath,
    # Output file, "-" for stdout
    [string]$Out = (Join-Path $HOME 'handoff.md'),
    # Also list tool calls, one line each
    [switch]$Tools
)

$configDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$root = Join-Path $configDir 'projects'

function Find-Newest($dir) {
    if (!(Test-Path -LiteralPath $dir)) { return }
    Get-ChildItem -LiteralPath $dir -Recurse -File -Filter "*$SessionId*.jsonl" |
        Where-Object { $_.FullName -notmatch '[\\/]subagents[\\/]' } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

if (!$SessionId -and !$ProjectPath) { $ProjectPath = (Get-Location).Path }
$f = $null
if ($ProjectPath) {
    $resolved = Resolve-Path -LiteralPath $ProjectPath -ErrorAction SilentlyContinue
    $p = if ($resolved) { $resolved.ProviderPath } else { $ProjectPath.TrimEnd('\', '/') }
    $f = Find-Newest (Join-Path $root ($p -replace '[^a-zA-Z0-9]', '-'))
    if (!$f) { Write-Host "No session found for project $p, searching all projects" }
}
if (!$f) { $f = Find-Newest $root }
if (!$f) { Write-Error "No Claude Code session matching '$SessionId' under $root"; exit 1 }

Write-Host $f.FullName

$msgs = New-Object System.Collections.Generic.List[object]
$skipped = 0
# Open with ReadWrite sharing so a session that is still running can be read
$fs = [System.IO.File]::Open($f.FullName, 'Open', 'Read', 'ReadWrite')
$reader = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
while ($null -ne ($line = $reader.ReadLine())) {
    if ($line -notmatch '"type":"(user|assistant|queued_command)"') { continue }
    try { $r = $line | ConvertFrom-Json -ErrorAction Stop } catch { $skipped++; continue }
    # Messages typed while Claude was working are stored as queued_command attachments
    $a = $r.attachment
    if ($r.type -eq 'attachment' -and $a.type -eq 'queued_command' -and (!$a.commandMode -or $a.commandMode -eq 'prompt')) {
        $r = [pscustomobject]@{ type = 'user'; isSidechain = $r.isSidechain; message = [pscustomobject]@{ content = $a.prompt } }
    }
    if ($r.type -notin 'user', 'assistant' -or $r.isSidechain -or $r.isMeta -or $r.isCompactSummary -or
        $r.isApiErrorMessage -or $r.message.model -eq '<synthetic>') { continue }

    $content = $r.message.content
    if ($content -is [string]) { $content = @([pscustomobject]@{ type = 'text'; text = $content }) }
    $parts = @(foreach ($b in $content) {
        switch ($b.type) {
            'text' {
                if ($b.text -and $b.text -cnotmatch '^\s*<[a-z][a-z0-9_-]*>' -and !$b.text.StartsWith('[Request interrupted')) { $b.text }
            }
            { $_ -in 'image', 'document' } { "[$($b.type)]" }
            'tool_use' {
                if ($Tools) {
                    $i = $b.input
                    $a = @($i.file_path, $i.command, $i.pattern, $i.url, $i.query, $i.description) |
                        Where-Object { $_ -is [string] -and $_ } | Select-Object -First 1
                    $a = "$a".Split("`n")[0]
                    if ($a.Length -gt 200) { $a = $a.Substring(0, 200) }
                    "> $($b.name): $a"
                }
            }
        }
    })
    if (!$parts.Count) { continue }

    $text = $parts -join "`n`n"
    $last = if ($msgs.Count) { $msgs[$msgs.Count - 1] }
    if ($last -and $last.role -eq $r.type) { $last.text += "`n`n" + $text }
    else { $msgs.Add([pscustomobject]@{ role = $r.type; text = $text }) }
}
$reader.Dispose()

if ($skipped) {
    Write-Warning "$skipped line(s) could not be parsed and were skipped (Windows PowerShell 5.1 cannot parse lines over ~2MB, usually large tool output; pwsh 7 can)"
}

$md = (@($msgs | ForEach-Object { "### $($_.role.ToUpper())`n$($_.text)`n" }) -join "`n") + "`n"
if ($Out -eq '-') { $md; return }
$Out = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
[System.IO.File]::WriteAllText($Out, $md, (New-Object System.Text.UTF8Encoding $false))
Write-Host "-> $Out"

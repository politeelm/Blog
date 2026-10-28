<#
  删除文章.ps1 —— 输入标题（可以只输一部分），找到文章，删除并推送

  用法：
    双击桌面上的「删文章」→ 弹出输入框，输标题 → 确认 → 自动删掉并推送
    或：.\删除文章.ps1 -标题 "楼下便利店"

  它会做四件事：
    1. 在 posts.js 里找到标题匹配的文章（模糊匹配，不用输全）
    2. 从喂 posts.js 和 feed.xml 里同时删掉
    3. 缓存版本号 +1
    4. 提交并推送

  只删本地不推送：加 -仅本地
#>

param(
  [string]$标题 = "",
  [string]$板块 = "",
  [switch]$仅本地,
  [switch]$不暂停,
  [switch]$跳过确认
)

$ErrorActionPreference = "Continue"

try {
  chcp 65001 | Out-Null
  [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
  $OutputEncoding = New-Object System.Text.UTF8Encoding($false)
} catch { }

$scriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDir)) { $scriptDir = (Get-Location).Path }
$root = Split-Path $scriptDir -Parent

# ---------------- 板块：cudm / dev ----------------
if ([string]::IsNullOrWhiteSpace($板块)) {
  $answer = ""
  try {
    Add-Type -AssemblyName Microsoft.VisualBasic | Out-Null
    $answer = [Microsoft.VisualBasic.Interaction]::InputBox("在哪个板块里删除？`n`n输入 cudm 或 dev，直接确定 = cudm", "选择板块", "cudm")
  } catch { $answer = "cudm" }
  if ([string]::IsNullOrWhiteSpace($answer)) { $answer = "cudm" }
  $板块 = $answer
}

$板块 = $板块.Trim().Trim("/").ToLower()
if ($板块 -ne "cudm" -and $板块 -ne "dev") {
  Write-Host "板块只能是 cudm 或 dev" -ForegroundColor Red
  Pause-Exit 1
}

$sectionDir = Join-Path $root $板块

function Pause-Exit([int]$code = 0) {
  if (-not $不暂停) { Read-Host "按回车关闭" | Out-Null }
  exit $code
}

function Show-Msg([string]$text, [string]$title = "删除文章") {
  try {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    [System.Windows.Forms.MessageBox]::Show($text, $title) | Out-Null
  } catch {
    Write-Host $text
  }
}

function Ask-Text([string]$prompt, [string]$title = "删除文章") {
  try {
    Add-Type -AssemblyName Microsoft.VisualBasic | Out-Null
    return [Microsoft.VisualBasic.Interaction]::InputBox($prompt, $title, "")
  } catch {
    return (Read-Host $prompt)
  }
}

function Step([string]$msg) { Write-Host $msg -ForegroundColor Cyan }

# ============================ 1. 要删哪篇 ============================

if ([string]::IsNullOrWhiteSpace($标题)) {
  $标题 = Ask-Text "输入文章标题，可以只输其中几个字："
  if ([string]::IsNullOrWhiteSpace($标题)) {
    Write-Host "已取消。" -ForegroundColor Yellow
    Pause-Exit 0
  }
}
$标题 = $标题.Trim()

$dataPath = Join-Path $sectionDir "posts.js"
$indexPath = Join-Path $sectionDir "index.html"
$feedPath = Join-Path $sectionDir "feed.xml"

foreach ($p in @($dataPath, $indexPath, $feedPath)) {
  if (-not (Test-Path -LiteralPath $p)) {
    Show-Msg "仓库文件缺失：$p"
    Pause-Exit 1
  }
}

# ============================ 2. 解析出所有文章 ============================

$text = [System.IO.File]::ReadAllText($dataPath, [System.Text.Encoding]::UTF8)

$startMarker = "/* POSTS:START */"
$endMarker = "/* POSTS:END */"
$startIdx = $text.IndexOf($startMarker)
$endIdx = $text.IndexOf($endMarker)

if ($startIdx -lt 0 -or $endIdx -lt 0 -or $endIdx -le $startIdx) {
  Show-Msg "posts.js 里找不到 POSTS:START / POSTS:END 标记，无法安全解析。"
  Pause-Exit 1
}

$prefix = $text.Substring(0, $startIdx + $startMarker.Length)
$region = $text.Substring($startIdx + $startMarker.Length, $endIdx - ($startIdx + $startMarker.Length))
$suffix = $text.Substring($endIdx)

# 每篇文章的形状：行首两个空格 + { ，结尾是行首两个空格 + },
$entryMatches = [regex]::Matches($region, '(?ms)^  \{\r?\n.*?^  \},')

if ($entryMatches.Count -eq 0) {
  Show-Msg "站上现在一篇文章都没有。"
  Pause-Exit 0
}

$entries = @()
foreach ($m in $entryMatches) {
  $block = $m.Value
  $slugMatch = [regex]::Match($block, 'slug:\s*"([^"]*)"')
  $titleMatch = [regex]::Match($block, 'title:\s*"((?:[^"\\]|\\.)*)"')
  $rawTitle = if ($titleMatch.Success) { $titleMatch.Groups[1].Value } else { "(无标题)" }
  $rawTitle = $rawTitle.Replace('\"', '"').Replace('\\', '\')
  $entries += [pscustomobject]@{
    Block = $block
    Slug  = if ($slugMatch.Success) { $slugMatch.Groups[1].Value } else { "" }
    Title = $rawTitle
  }
}

# ============================ 3. 匹配 ============================

$hits = @($entries | Where-Object { $_.Title.IndexOf($标题, [StringComparison]::OrdinalIgnoreCase) -ge 0 })

if ($hits.Count -eq 0) {
  $list = ($entries | ForEach-Object { "· " + $_.Title }) -join "`n"
  Show-Msg "没有找到标题包含「$标题」的文章。`n`n现在站上有这些：`n$list"
  Pause-Exit 0
}

if ($hits.Count -gt 1) {
  $list = ($hits | ForEach-Object { "· " + $_.Title }) -join "`n"
  $answer = Ask-Text "匹配到 $($hits.Count) 篇，输入序号删除（1 开始）：`n`n$list"
  $n = 0
  if (-not [int]::TryParse($answer, [ref]$n) -or $n -lt 1 -or $n -gt $hits.Count) {
    Show-Msg "序号不对，已取消。"
    Pause-Exit 0
  }
  $hits = @($hits[$n - 1])
}

$target = $hits[0]

if (-not $跳过确认) {
try {
  Add-Type -AssemblyName System.Windows.Forms | Out-Null
  $confirm = [System.Windows.Forms.MessageBox]::Show(
    "确定删除这篇吗？`n`n$($target.Title)`n`n（删除后会立即推送上线）",
    "删除文章",
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Warning)
  if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
    Show-Msg "已取消，什么都没删。"
    Pause-Exit 0
  }
} catch { }
}

# ============================ 4. 从 posts.js 删除 ============================

$newRegion = $region.Replace($target.Block, "")
# 清理多余空行
$newRegion = [regex]::Replace($newRegion, "(\r?\n){3,}", "`r`n`r`n")
if ($newRegion -notmatch '\S') { $newRegion = "`r`n  " }

$newText = $prefix + $newRegion + $suffix
[System.IO.File]::WriteAllText($dataPath, $newText, (New-Object System.Text.UTF8Encoding($false)))
Step "已从 posts.js 删除：$($target.Title)"

# ============================ 5. 从 feed.xml 删除 ============================

$feedText = [System.IO.File]::ReadAllText($feedPath, [System.Text.Encoding]::UTF8)
$itemMatches = [regex]::Matches($feedText, '(?s)\s*<item>.*?</item>')
$removed = 0
foreach ($m in $itemMatches) {
  $slug = $target.Slug
  if ($slug -and $m.Value.Contains("/post/$slug")) {
    $feedText = $feedText.Replace($m.Value, "")
    $removed++
  }
}
if ($removed -gt 0) {
  $feedText = [regex]::Replace($feedText, "(\r?\n){3,}", "`r`n`r`n")
  [System.IO.File]::WriteAllText($feedPath, $feedText, (New-Object System.Text.UTF8Encoding($false)))
  Step "已从 feed.xml 删除 $removed 条"
} else {
  Write-Host "feed.xml 里没有对应条目，跳过" -ForegroundColor Yellow
}

# ============================ 6. 版本号 +1 ============================

$html = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8)
$found = [regex]::Matches($html, '\?v=(\d+)')
if ($found.Count -gt 0) {
  $current = 0
  foreach ($m in $found) {
    $n = [int]$m.Groups[1].Value
    if ($n -gt $current) { $current = $n }
  }
  $next = $current + 1
  $html = [regex]::Replace($html, '\?v=\d+', ('?v=' + $next))
  [System.IO.File]::WriteAllText($indexPath, $html, (New-Object System.Text.UTF8Encoding($false)))
  Step "缓存版本号：v$current → v$next"
}

# ============================ 7. 提交并推送 ============================

$剩余 = @($entries | Where-Object { $_.Slug -ne $target.Slug }).Count
Write-Host ""
Write-Host "已删除：$($target.Title)"
Write-Host "剩余文章：$剩余 篇"

if (-not (Test-Path (Join-Path $root ".git"))) {
  Show-Msg "这里不是 git 仓库，只删了本地文件，没有推送。"
  Pause-Exit 0
}

if ($仅本地) {
  Show-Msg "已删除（-仅本地，没有提交推送）。"
  Pause-Exit 0
}

Set-Location $root
git add -A 2>$null
if ($LASTEXITCODE -ne 0) { Show-Msg "git add 失败"; Pause-Exit 1 }

$message = "删除文章：$($target.Title)"
git commit -q -m $message 2>$null
if ($LASTEXITCODE -ne 0) { Show-Msg "git commit 失败"; Pause-Exit 1 }
Step "已提交：$message"

$ok = $false
for ($i = 1; $i -le 4; $i++) {
  git push -u origin HEAD 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0) { $ok = $true; Step "推送成功（第 $i 次尝试）"; break }
  Write-Host "第 $i 次推送失败（多半是网络），5 秒后重试…" -ForegroundColor Yellow
  Start-Sleep -Seconds 5
}

if (-not $ok) {
  Show-Msg "推送失败，但删除已经提交在本地。网络好了执行 git push 即可。"
  Pause-Exit 1
}

Show-Msg "已删除并推送：`n`n$($target.Title)`n`n站点还剩 $剩余 篇文章。`n大约 1 分钟后生效。"
Write-Host "完成。约 1 分钟后生效：https://politeelm.github.io/Blog/" -ForegroundColor Green
Pause-Exit 0

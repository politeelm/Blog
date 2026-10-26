<#
  新建文章.ps1 —— 一条命令生成新文章，并同步 RSS

  用法（在本文件夹里打开 PowerShell）：
    .\新建文章.ps1 -标题 "今天的晚饭" -摘要 "一句话介绍" -标签 "生活,随笔" -文件名 dinner

  参数：
    -标题     必填。文章标题。
    -摘要     可选。显示在卡片和 RSS 里。
    -标签     可选。多个用逗号隔开。
    -文件名   可选。文章 id（建议英文），会出现在网址 #/post/xxx 里。
    -站点地址 可选。写 RSS 用的完整网址。

  它会做三件事：
    1. 往 assets/js/posts.js 里插入一篇文章数据（正文先放占位内容）
    2. 往 feed.xml 里插入一条
    3. 打印接下来该改哪个文件的哪一段
#>

param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$标题,

  [string]$摘要 = "",
  [string]$标签 = "",
  [string]$文件名 = "",
  [string]$站点地址 = "https://politeelm.github.io/Blog"
)

$ErrorActionPreference = "Stop"
$nl = "`r`n"

function JsString([string]$value) {
  if ($null -eq $value) { return '""' }
  $v = $value.Replace("\", "\\").Replace('"', '\"')
  $v = $v.Replace("`r", " ").Replace("`n", " ")
  return '"' + $v + '"'
}

function XmlEscape([string]$value) {
  if ($null -eq $value) { return "" }
  return $value.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace('"', "&quot;").Replace("'", "&apos;")
}

function Insert-AfterMarker {
  param([string]$Path, [string]$Marker, [string]$Block)

  if (-not (Test-Path -LiteralPath $Path)) { throw "找不到文件：$Path" }

  $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
  if (-not $text.Contains($Marker)) { throw "在 $Path 里找不到标记：$Marker" }

  $text = $text.Replace($Marker, $Marker + $nl + $Block.TrimEnd() + $nl)
  [System.IO.File]::WriteAllText($Path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

# ---------- 准备 ----------

$root = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($root)) { $root = (Get-Location).Path }

$dataPath = Join-Path $root "assets\js\posts.js"
if (-not (Test-Path -LiteralPath $dataPath)) { throw "找不到数据文件：$dataPath" }

$date = Get-Date -Format "yyyy-MM-dd"

if ([string]::IsNullOrWhiteSpace($文件名)) {
  $文件名 = "post-" + (Get-Date -Format "yyyyMMdd-HHmm")
}

$slug = ($文件名.Trim() -replace "[^\p{L}\p{Nd}\-]", "-").Trim("-").ToLower()
if ([string]::IsNullOrWhiteSpace($slug)) {
  $slug = "post-" + (Get-Date -Format "yyyyMMdd-HHmm")
}

$existing = Get-Content -Raw -Encoding UTF8 -LiteralPath $dataPath
if ($existing.Contains('slug: "' + $slug + '"')) {
  throw "这个 id 已经被用了：$slug （换一个 -文件名 再试）"
}

# ---------- 标签 ----------

$tagList = @()
if (-not [string]::IsNullOrWhiteSpace($标签)) {
  $tagList = $标签 -split "[,，]" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

$tagsJs = if ($tagList.Count -gt 0) {
  "[" + (($tagList | ForEach-Object { JsString $_ }) -join ", ") + "]"
} else {
  "[]"
}

# ---------- 往 posts.js 插入 ----------

$summaryText = if ([string]::IsNullOrWhiteSpace($摘要)) { "（在这里写一句话摘要）" } else { $摘要 }

$postBlock = @"
  {
    slug: "$slug",
    title: $(JsString $标题),
    date: "$date",
    tags: $tagsJs,
    summary: $(JsString $summaryText),
    content: ``
      <p>在这里写正文。</p>

      <h2>小标题</h2>
      <p>段落……</p>
    ``
  },
"@

Insert-AfterMarker -Path $dataPath -Marker "/* POSTS:START */" -Block $postBlock

# ---------- 往 feed.xml 插入 ----------

$url = $站点地址.TrimEnd("/") + "/#/post/$slug"
$pubDate = (Get-Date).ToString("ddd, dd MMM yyyy HH:mm:ss zzz", [System.Globalization.CultureInfo]::InvariantCulture)

$feedBlock = @"
    <item>
      <title>$(XmlEscape $标题)</title>
      <link>$url</link>
      <guid isPermaLink="false">$url</guid>
      <pubDate>$pubDate</pubDate>
      <description>$(XmlEscape $摘要)</description>
    </item>
"@

Insert-AfterMarker -Path (Join-Path $root "feed.xml") -Marker "<!-- ITEMS:START -->" -Block $feedBlock

# ---------- 完成 ----------

Write-Host ""
Write-Host "已创建文章：$标题" -ForegroundColor Green
Write-Host "  位置：assets\js\posts.js（数组最上面那一条）"
Write-Host "  地址：#/post/$slug"
Write-Host ""
Write-Host "接下来：" -ForegroundColor Cyan
Write-Host "  1. 打开 assets\js\posts.js，把 content 里的占位内容换成正文"
Write-Host "  2. 刷新 index.html 看看效果"
Write-Host "  3. git add -A; git commit -m '新文章'; git push"
Write-Host ""

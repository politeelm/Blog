<#
  发布文章.ps1 —— 读一个 txt，自动生成文章、更新 RSS、推送上线

  txt 格式（前 3 行固定，第 4 行往后是正文）：
    第 1 行：标题
    第 2 行：摘要
    第 3 行：标签，用逗号隔开（中英文逗号都行），如：奇异人士,devlog
    第 4 行起：正文

  正文支持的简易写法（不写也能用，一行就是一段）：
    ## 小标题        → <h2>
    > 引用的话       → <blockquote>
    - 列表项         → <ul><li>
    （空行会被忽略）

  用法：
    双击桌面上的「发文章」→ 弹出选择框，选 txt
    或：.\发布文章.ps1 -文件 "C:\path\to\文章.txt"
    只生成不推送：加 -仅本地
#>

param(
  [string]$文件 = "",
  [string]$板块 = "",
  [switch]$仅本地,
  [switch]$不暂停
)

$ErrorActionPreference = "Continue"

# 控制台中文别乱码
try {
  chcp 65001 | Out-Null
  [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
  $OutputEncoding = New-Object System.Text.UTF8Encoding($false)
} catch { }

$scriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDir)) { $scriptDir = (Get-Location).Path }
$root = Split-Path $scriptDir -Parent     # 仓库根目录（工具 的上一级）


$nl = "`r`n"

# ============================ 小工具 ============================

function Pause-Exit([int]$code = 0) {
  if (-not $不暂停) { Read-Host "按回车关闭" | Out-Null }
  exit $code
}

function Escape-Html([string]$s) {
  if ($null -eq $s) { return "" }
  return $s.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;")
}

function Escape-Template([string]$s) {
  # posts.js 的 content 是模板字符串，反引号和 ${ 要转义
  if ($null -eq $s) { return "" }
  return $s.Replace('`', '\`').Replace('${', '\${')
}

function Escape-Js([string]$s) {
  if ($null -eq $s) { return '""' }
  $v = $s.Replace("\", "\\").Replace('"', '\"')
  $v = $v.Replace("`r", " ").Replace("`n", " ")
  return '"' + $v + '"'
}

function Escape-Xml([string]$s) {
  if ($null -eq $s) { return "" }
  return $s.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace('"', "&quot;")
}

function Read-TextSmart([string]$path) {
  $bytes = [System.IO.File]::ReadAllBytes($path)
  $utf8 = [System.Text.Encoding]::UTF8.GetString($bytes)
  # UTF-8 解码出现替换字符，说明原本不是 UTF-8，退回系统默认编码（中文 Windows 即 GBK）
  if ($utf8.IndexOf([char]0xFFFD) -ge 0) {
    try { return [System.Text.Encoding]::GetEncoding(936).GetString($bytes) } catch { return $utf8 }
  }
  return $utf8
}

function Convert-BodyToHtml($lines) {
  $out = New-Object System.Text.StringBuilder
  $inList = $false

  foreach ($raw in $lines) {
    $line = $raw.TrimEnd()
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $t = $line.Trim()

    if ($t.StartsWith("- ")) {
      if (-not $inList) { [void]$out.AppendLine("      <ul>"); $inList = $true }
      [void]$out.AppendLine("        <li>" + (Escape-Html $t.Substring(2).Trim()) + "</li>")
      continue
    }

    if ($inList) { [void]$out.AppendLine("      </ul>"); $inList = $false }

    # 图片：![说明](路径)  整行生效
    $img = [regex]::Match($t, '^!\[(.*?)\]\((.+?)\)$')
    if ($img.Success) {
      $caption = $img.Groups[1].Value.Trim()
      $src = $img.Groups[2].Value.Trim()
      if ($script:imageMap.ContainsKey($src)) { $src = $script:imageMap[$src] }
      $srcAttr = Escape-Html $src
      $capAttr = Escape-Html $caption

      if ($caption) {
        [void]$out.AppendLine("      <figure><img src=`"$srcAttr`" alt=`"$capAttr`" loading=`"lazy`"><figcaption>$capAttr</figcaption></figure>")
      } else {
        [void]$out.AppendLine("      <img src=`"$srcAttr`" alt=`"`" loading=`"lazy`">")
      }
      continue
    }

    if ($t.StartsWith("## ")) {
      [void]$out.AppendLine("      <h2>" + (Escape-Html $t.Substring(3).Trim()) + "</h2>")
    } elseif ($t.StartsWith("> ")) {
      [void]$out.AppendLine("      <blockquote><p>" + (Escape-Html $t.Substring(2).Trim()) + "</p></blockquote>")
    } else {
      [void]$out.AppendLine("      <p>" + (Escape-Html $t) + "</p>")
    }
  }

  if ($inList) { [void]$out.AppendLine("      </ul>") }
  return $out.ToString().TrimEnd()
}

function Insert-AfterMarker([string]$path, [string]$marker, [string]$block) {
  $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
  if (-not $text.Contains($marker)) { throw "在 $path 里找不到插入标记：$marker" }
  $text = $text.Replace($marker, $marker + $nl + $block.TrimEnd() + $nl)
  [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

$script:imageMap = @{}

function Resolve-Images($lines, [string]$sourceDir) {
  foreach ($raw in $lines) {
    $t = $raw.Trim()
    if ([string]::IsNullOrWhiteSpace($t)) { continue }

    $m = [regex]::Match($t, '^!\[(.*?)\]\((.+?)\)$')
    if (-not $m.Success) { continue }

    $src = $m.Groups[2].Value.Trim()
    if ($src -match '^(https?:)?//' -or $src -match '^data:') { continue }
    if ($script:imageMap.ContainsKey($src)) { continue }

    $candidate = if ([IO.Path]::IsPathRooted($src)) { $src } else { Join-Path $sourceDir $src }

    if (-not (Test-Path -LiteralPath $candidate)) {
      Write-Host "  ⚠ 找不到图片：$candidate（按原路径写进文章）" -ForegroundColor Yellow
      $script:imageMap[$src] = $src
      continue
    }

    $imgDir = Join-Path $root "assets\images"
    if (-not (Test-Path -LiteralPath $imgDir)) {
      New-Item -ItemType Directory -Path $imgDir -Force | Out-Null
    }

    $name = [IO.Path]::GetFileName($candidate)
    $name = ($name -replace '[^\w\.\-]', '_')
    $target = Join-Path $imgDir $name

    # 同名但内容不同 → 加时间戳，避免互相覆盖
    if ((Test-Path -LiteralPath $target) -and
        ((Get-FileHash -LiteralPath $target).Hash -ne (Get-FileHash -LiteralPath $candidate).Hash)) {
      $baseName = [IO.Path]::GetFileNameWithoutExtension($name)
      $ext = [IO.Path]::GetExtension($name)
      $name = $baseName + "-" + (Get-Date -Format "HHmmss") + $ext
      $target = Join-Path $imgDir $name
    }

    Copy-Item -LiteralPath $candidate -Destination $target -Force
    $script:imageMap[$src] = "../assets/images/$name"

    $size = (Get-Item -LiteralPath $target).Length
    Write-Host ("  图片已复制：{0} → assets/images/{1}（{2:N0} KB）" -f $src, $name, ($size / 1KB)) -ForegroundColor DarkGray

    if ($size -gt 2MB) {
      Write-Host ("  ⚠ 这张图 {0} MB，建议压到 500KB 以内，否则读者要等" -f [math]::Round($size / 1MB, 1)) -ForegroundColor Yellow
    }
  }
}

function Select-Section([string]$prompt = "选择板块") {
  try {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    Add-Type -AssemblyName System.Drawing | Out-Null
  } catch {
    # 图形界面起不来时退回命令行输入（-不暂停 的自动化场景下不阻塞）
    if (-not $不暂停) {
      Write-Host "图形界面不可用，改用手动输入。" -ForegroundColor Yellow
      $ans = (Read-Host "输入 cudm 或 dev").Trim().ToLower()
      if ($ans -eq "dev" -or $ans -eq "cudm") { return $ans }
    }
    return $null
  }

  $form = New-Object System.Windows.Forms.Form
  $form.Text = "选择板块"
  $form.ClientSize = New-Object System.Drawing.Size(360, 208)
  $form.StartPosition = "CenterScreen"
  $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
  $form.MaximizeBox = $false
  $form.MinimizeBox = $false
  $form.TopMost = $true

  $label = New-Object System.Windows.Forms.Label
  $label.Text = $prompt
  $label.SetBounds(22, 18, 316, 24)
  $form.Controls.Add($label)

  $b1 = New-Object System.Windows.Forms.Button
  $b1.Text = "cudm · 奇人异事"
  $b1.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10)
  $b1.SetBounds(22, 52, 316, 44)
  $b1.Add_Click({ $script:chosenSection = "cudm"; $form.Close() })

  $b2 = New-Object System.Windows.Forms.Button
  $b2.Text = "dev · 项目简介"
  $b2.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10)
  $b2.SetBounds(22, 102, 316, 44)
  $b2.Add_Click({ $script:chosenSection = "dev"; $form.Close() })

  $b3 = New-Object System.Windows.Forms.Button
  $b3.Text = "取消"
  $b3.SetBounds(22, 154, 316, 32)
  $b3.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

  $form.Controls.AddRange(@($b1, $b2, $b3))
  $form.CancelButton = $b3

  $script:chosenSection = $null
  [void]$form.ShowDialog()
  $form.Dispose()
  return $script:chosenSection
}

function Step([string]$msg) { Write-Host $msg -ForegroundColor Cyan }

# ============================ 1. 选文件 ============================

if ([string]::IsNullOrWhiteSpace($文件)) {
  Add-Type -AssemblyName System.Windows.Forms | Out-Null
  $dialog = New-Object System.Windows.Forms.OpenFileDialog
  $dialog.Title = "选择要发布的文章（txt）"
  $dialog.Filter = "文本文件 (*.txt)|*.txt|所有文件 (*.*)|*.*"
  $dialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")

  if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "已取消。" -ForegroundColor Yellow
    Pause-Exit 0
  }
  $文件 = $dialog.FileName
}

if (-not (Test-Path -LiteralPath $文件)) {
  Write-Host "找不到文件：$文件" -ForegroundColor Red
  Pause-Exit 1
}

# 拖进来的是文件夹？自动找里面的 txt（拖整个文件夹也能用）
if ((Get-Item -LiteralPath $文件).PSIsContainer) {
  $folder = (Get-Item -LiteralPath $文件).FullName
  Write-Host "检测到文件夹：$folder" -ForegroundColor Yellow

  $txts = @(Get-ChildItem -LiteralPath $folder -Filter *.txt -File -ErrorAction SilentlyContinue)

  if ($txts.Count -eq 0) {
    Write-Host "这个文件夹里没有 .txt 文件。" -ForegroundColor Red
    Write-Host "要么把 txt 放进这个文件夹，要么直接选那个 txt 文件。" -ForegroundColor Yellow
    Pause-Exit 1
  }

  if ($txts.Count -eq 1) {
    $文件 = $txts[0].FullName
  } else {
    # 多个 txt 时，优先选和文件夹同名的那个
    $sameName = $txts | Where-Object { $_.BaseName -eq (Split-Path $folder -Leaf) } | Select-Object -First 1
    if ($sameName) {
      $文件 = $sameName.FullName
    } else {
      Write-Host "文件夹里有 $($txts.Count) 个 txt：" -ForegroundColor Yellow
      for ($k = 0; $k -lt $txts.Count; $k++) { Write-Host ("  [{0}] {1}" -f ($k + 1), $txts[$k].Name) }
      $pick = Read-Host "输入序号选一个（直接回车用第 1 个）"
      $n = 1
      if (-not [int]::TryParse($pick, [ref]$n) -or $n -lt 1 -or $n -gt $txts.Count) { $n = 1 }
      $文件 = $txts[$n - 1].FullName
    }
  }

  Write-Host "使用：$文件" -ForegroundColor Green
}

# ============================ 2. 解析 ============================

Step "读取：$文件"

try {
  $raw = Read-TextSmart $文件
} catch {
  Write-Host ""
  Write-Host "读不了这个文件：$文件" -ForegroundColor Red
  Write-Host "常见原因：选错了文件夹、文件被别的程序占用（比如记事本/Word 还开着）、或者没有读取权限。" -ForegroundColor Yellow
  Write-Host "把文件关掉再试，或者直接把那个 .txt 拖到「发文章」图标上。" -ForegroundColor Yellow
  Pause-Exit 1
}

$raw = $raw.TrimStart([char]0xFEFF)
$lines = $raw -split "\r?\n"

if ($lines.Count -lt 3) {
  Write-Host "格式不对：至少需要 3 行（标题 / 摘要 / 标签）" -ForegroundColor Red
  Pause-Exit 1
}

$title = $lines[0].Trim()
$summary = $lines[1].Trim()
$tagsLine = $lines[2].Trim()
$bodyLines = if ($lines.Count -gt 3) { $lines[3..($lines.Count - 1)] } else { @() }

if ([string]::IsNullOrWhiteSpace($title)) {
  Write-Host "第 1 行（标题）是空的。" -ForegroundColor Red
  Pause-Exit 1
}

$sourceDir = (Get-Item -LiteralPath $文件).DirectoryName
Resolve-Images $bodyLines $sourceDir
$bodyHtml = Convert-BodyToHtml $bodyLines
if ([string]::IsNullOrWhiteSpace($bodyHtml)) {
  Write-Host "正文是空的（第 4 行往后没有内容）。" -ForegroundColor Red
  Pause-Exit 1
}

$tags = @()
if (-not [string]::IsNullOrWhiteSpace($tagsLine)) {
  $tags = @($tagsLine -split "[,，]" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

# ============================ 选板块（发布前手动选） ============================

if ([string]::IsNullOrWhiteSpace($板块)) {
  $板块 = Select-Section "这篇要发到哪个板块？"
  if ([string]::IsNullOrWhiteSpace($板块)) {
    Write-Host "已取消，什么都没做。" -ForegroundColor Yellow
    Pause-Exit 0
  }
}

$板块 = $板块.Trim().Trim("/").ToLower()
if ($板块 -ne "cudm" -and $板块 -ne "dev") {
  Write-Host "板块只能是 cudm 或 dev，收到的是：$板块" -ForegroundColor Red
  Pause-Exit 1
}

$sectionDir = Join-Path $root $板块
$siteUrl = "https://politeelm.github.io/$板块"

# ============================ 3. 生成信息 ============================

$date = (Get-Item -LiteralPath $文件).LastWriteTime.ToString("yyyy-MM-dd")

$baseName = [System.IO.Path]::GetFileNameWithoutExtension($文件)
if ($baseName -match '^[A-Za-z0-9\-_]+$') {
  $slug = $baseName.ToLower()
} else {
  $slug = "post-" + (Get-Date -Format "yyyyMMdd-HHmmss")
  Write-Host "提示：文件名不是纯英文，文章地址用时间戳 $slug" -ForegroundColor Yellow
}

$dataPath = Join-Path $sectionDir "posts.js"
$indexPath = Join-Path $sectionDir "index.html"
$feedPath = Join-Path $sectionDir "feed.xml"
foreach ($p in @($dataPath, $indexPath, $feedPath)) {
  if (-not (Test-Path -LiteralPath $p)) {
    Write-Host "仓库文件缺失：$p" -ForegroundColor Red
    Pause-Exit 1
  }
}

$existing = [System.IO.File]::ReadAllText($dataPath, [System.Text.Encoding]::UTF8)
if ($existing.Contains('slug: "' + $slug + '"')) {
  Write-Host "已经有 slug 为「$slug」的文章了，换个文件名再试。" -ForegroundColor Red
  Pause-Exit 1
}

$tagsJs = "[" + (($tags | ForEach-Object { Escape-Js $_ }) -join ", ") + "]"

# ============================ 4. 写入 posts.js ============================

$postBlock = @"
  {
    slug: "$slug",
    title: $(Escape-Js $title),
    date: "$date",
    tags: $tagsJs,
    summary: $(Escape-Js $summary),
    content: ``
$(Escape-Template $bodyHtml)
    ``
  },
"@

try {
  Insert-AfterMarker $dataPath "/* POSTS:START */" $postBlock
} catch {
  Write-Host $_.Exception.Message -ForegroundColor Red
  Pause-Exit 1
}
Step "文章已写入 posts.js"

# ============================ 5. 缓存版本号 +1 ============================

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

# ============================ 6. 写入 feed.xml ============================

$url = "$siteUrl/#/post/$slug"
$pubDate = (Get-Date).ToString("ddd, dd MMM yyyy HH:mm:ss zzz", [Globalization.CultureInfo]::InvariantCulture)
$feedBlock = @"
    <item>
      <title>$(Escape-Xml $title)</title>
      <link>$url</link>
      <guid isPermaLink="false">$url</guid>
      <pubDate>$pubDate</pubDate>
      <description>$(Escape-Xml $summary)</description>
    </item>
"@
Insert-AfterMarker $feedPath "<!-- ITEMS:START -->" $feedBlock
Step "RSS 已更新"

# ============================ 7. 提交并推送 ============================

Write-Host ""
Write-Host "标题：$title"
Write-Host "日期：$date"
Write-Host "标签：$($tags -join ' / ')"
Write-Host "地址：$url"
Write-Host ""

if (-not (Test-Path (Join-Path $root ".git"))) {
  Write-Host "（这里不是 git 仓库，只生成没推送）" -ForegroundColor Yellow
  Pause-Exit 0
}

if ($仅本地) {
  Write-Host "（-仅本地，已生成但没提交）" -ForegroundColor Yellow
  Pause-Exit 0
}

Set-Location $root
git add -A 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "git add 失败" -ForegroundColor Red; Pause-Exit 1 }

$message = "新增文章：$title"
git commit -q -m $message 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "git commit 失败" -ForegroundColor Red; Pause-Exit 1 }
Step "已提交：$message"

$ok = $false
for ($i = 1; $i -le 4; $i++) {
  git push -u origin HEAD 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0) { $ok = $true; Step "推送成功（第 $i 次尝试）"; break }
  Write-Host "第 $i 次推送失败（多半是网络），5 秒后重试…" -ForegroundColor Yellow
  Start-Sleep -Seconds 5
}

if (-not $ok) {
  Write-Host "推送失败，但改动已经提交在本地。网络好了执行 git push 即可。" -ForegroundColor Red
  Pause-Exit 1
}

Write-Host ""
Write-Host "大约 1 分钟后生效：$url" -ForegroundColor Green
Write-Host "打开后如果还是旧内容，按 Ctrl + F5 强刷。" -ForegroundColor Green
Pause-Exit 0
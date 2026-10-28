# L1MA0 · 个人网页（单页交互版）

一个**零依赖的单页博客**：纯 HTML + CSS + 原生 JS，没有 Node、没有构建、没有数据库。
双击 `index.html` 就能用，推送到 GitHub Pages 就能上线。

已经做好的交互：

- **分页** —— 上一页 / 下一页 / 页码，地址栏会跟着变（`#/?page=2`）
- **标签筛选** —— 点标签只看这一类（`#/?tag=读书`）
- **实时搜索** —— 边打字边过滤，同时搜索标题、摘要和正文
- **排序切换** —— 最新在前 / 最早在前
- **文章页** —— 阅读时长、字数、上一篇/下一篇、正文页码进度条
- **深色模式** —— 跟随系统，可手动切换并记住（快捷键 `T`）
- **回到顶部** —— 滚动到一半才出现

---

## 一、先看一眼

双击 `index.html` 即可。地址栏里出现 `#/...` 是正常的，这个博客靠它做页面切换。

想用本地服务器预览（表现和线上完全一致）：

```powershell
python -m http.server 8000
```

然后访问 <http://localhost:8000>。

---

## 二、目录结构

```
politeelm.github.io/          ← 仓库名就是域名，一个仓库装下整站
├── index.html                主页：个人介绍 + 两个板块入口
├── cudm/                     ★ 板块一：奇人异事
│   ├── index.html            列表 / 文章 / 标签 / 关于（同一个文件渲染）
│   ├── posts.js              板块配置 + 本板块所有文章
│   ├── feed.xml              本板块 RSS
│   └── 404.html
├── dev/                      ★ 板块二：项目简介（结构和 cudm 完全一样）
│   ├── index.html
│   ├── posts.js              这里放着 PCL2-plus 那篇
│   ├── feed.xml
│   └── 404.html
├── assets/                   两个板块共用
│   ├── css/style.css         板块样式
│   ├── css/home.css          主页样式
│   ├── js/app.js             路由、分页、筛选、搜索、灯箱
│   ├── js/main.js            深色模式
│   └── images/               文章图片、网站图标
├── 工具/发布文章.ps1          txt → 文章 → 推送
├── 工具/删除文章.ps1          标题 → 删除 → 推送
├── 发布.ps1                  版本号 +1、提交、推送
└── README.md
```

**地址对照**

| 地址 | 内容 |
| --- | --- |
| `politeelm.github.io/` | 主页，选板块 |
| `politeelm.github.io/cudm/` | cudm 奇人异事 |
| `politeelm.github.io/dev/` | dev 项目简介 |

两个板块的代码是同一份（`assets/js/app.js`），只有 `posts.js` 里的配置和文章不同。
所以改样式、改功能，两个板块一起变；加文章只影响各自板块。
---

## 三、改成你自己的（5 分钟）

### 1. 站点信息

打开对应板块的 `posts.js`（`cudm/posts.js` 或 `dev/posts.js`），最上面的 `BLOG_CONFIG` 就是全部可配置项：

```js
window.BLOG_CONFIG = {
  title: "L1MA0",        // 站点名（浏览器标签页、页脚）
  tagline: "慢慢写，慢慢记。", // 首页大标题
  intro: "这里存放……",       // 首页那段介绍
  author: "L1MA0",            // 关于页
  email: "steamryy@outlook.com",  // 关于页（投稿邮箱）
  siteUrl: "https://politeelm.github.io/cudm",   // 每个板块不一样
  counterPath: "politeelm.github.io/cudm",      // 计数徽章用的路径
  perPage: 4,                 // ★ 每页显示几篇，改这个就改分页
  tags: ["奇异人士", ...],     // ★ 标签清单：写了就会出现在筛选栏，没文章也显示
  links: [...]                // 首页那排小按钮
};
```

另外 `index.html` 里的 `<title>`、页头 `.brand`、页脚要手动改成你的站名。

### 2. 配色

`assets/css/style.css` 最上面的 `:root` 和 `html[data-theme="dark"]`，
改 `--accent` 一行就能换掉整站主题色。

---

## 四、写一篇新文章

### 方法 A：用脚本（推荐）

在文件夹里 `Shift` + 右键 → 「在此处打开 PowerShell 窗口」：

```powershell
.\新建文章.ps1 -标题 "今天的晚饭" -摘要 "一顿很普通的饭" -标签 "生活,随笔" -文件名 dinner
```

脚本会往 `posts.js` 顶部插入一条数据、往 `feed.xml` 插入一条，然后打印接下来该干什么。
工具会自动改好对应板块的 `posts.js`，不用你手动找文件。

如果提示「无法加载文件…因为在此系统上禁止运行脚本」，执行一次这个（只影响当前用户）：

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

然后关掉 PowerShell 窗口重新开一个，脚本就能直接运行了。
临时替代方案：`powershell -ExecutionPolicy Bypass -File .\新建文章.ps1`

### 方法 B：手动加

在 `posts.js` 的 `/* POSTS:START */` 下面加一个对象：

```js
{
  slug: "dinner",                       // 网址 #/post/dinner，别和别人重名
  title: "今天的晚饭",
  date: "2026-10-27",                   // 排序按这个
  tags: ["生活", "随笔"],
  summary: "一顿很普通的饭。",           // 卡片和 RSS 里显示
  content: `
    <p>正文第一段。</p>
    <h2>小标题</h2>
    <p>更多内容。</p>
  `
},
```

> ⚠️ `content` 用的是模板字符串，里面**不要出现反引号 ` 和 `${`**。
> 需要代码示例时用 `<code>` / `<pre>` 标签，不要用 Markdown 语法。

### 在正文里插图片

**用桌面工具发文时**：把图片和 txt 放在同一个文件夹，正文里写一行就行：

```
![图注写在这里](photo.jpg)
```

发布时工具会自动把图片复制进 `assets/images/`，并生成带图注的 `<figure>`。
图注留空就写 `![](photo.jpg)`，只出图不出字。也支持子路径（`images/photo.jpg`）和网址（`https://...`，不会复制）。

**直接改 `posts.js` 时**，手写 HTML：

```html
<figure>
  <img src="assets/images/photo.jpg" alt="说明" loading="lazy">
  <figcaption>图片下面的说明文字</figcaption>
</figure>
```

图片放 `assets/images/`。站点上的图片**点一下会放大**，按 `Esc` 或点击空白处关闭。

建议单张压到 500KB 以内（手机原图动辄 3–5MB，读者要等很久）。

### 正文能用的标签

`<h2>` `<h3>` 小标题、`<p>` 段落、`<ul>`/`<ol>` 列表、`<blockquote>` 引用、
`<pre><code>` 代码块、`<strong>` 加粗、`<em>` 斜体、`<img>` 图片、`<table>` 表格——样式都写好了。

图片放到 `assets/images/`（需要自己建），写 `<img src="assets/images/a.jpg" alt="描述">`。

### 增删文章之后

不用改别的地方。分页、标签云、标签数量、上一篇/下一篇全是自动算的。

---

## 五、发布到 GitHub Pages

仓库名必须是 **`politeelm.github.io`**（正好等于你的域名），选 **Public**。
这样 Pages 从根路径提供服务，`/cudm/`、`/dev/` 才对得上。

从旧的 `Blog` 仓库改名即可：**Settings → Rename** → 填 `politeelm.github.io`。
提交历史、Pages 配置都保留，只是地址从 `/Blog/` 变成根路径。

### 推上去

```powershell
git add -A
git commit -m "改成主页 + 两个板块"
git push
```

改名后远程地址也变了，如果 push 报错就先改一下：

```powershell
git remote set-url origin https://github.com/politeelm/politeelm.github.io.git
```

### Pages 设置

仓库 → **Settings → Pages**：Source 选 `Deploy from a branch`，
Branch 选 `main` + `/ (root)`，Save。

```
仓库名 politeelm.github.io  →  https://politeelm.github.io/
```

以后每次更新：

```powershell
.\发布.ps1 -消息 "说明"
```

## 六、改完没生效？（缓存）

GitHub Pages 给 js/css 设了约 10 分钟缓存，浏览器会先用本地副本。
所以 index.html 里的资源都带着 `?v=2` 这种版本号：

```html
<script src="assets/js/app.js?v=2"></script>
```

**只要你改了 js 或 css，就把 ?v= 后面的数字 +1**（2 → 3 → 4…），推送后访问者立刻拿到新版。
只改文章内容（posts.js）也一样，因为它也是这么引的。

急着看效果又不想改版本号的话：按 `Ctrl + F5` 强制刷新。

## 七、浏览量是怎么算的

列表页和文章页那两个小徽章，用的是 [hits.sh](https://hits.sh) 的免费 SVG 计数图（不用注册）。
图片每加载一次算一次浏览，加载失败会自动隐藏，不影响排版。

- 板块总浏览：`hits.sh/politeelm.github.io/cudm/index.svg`
- 单篇阅读：`hits.sh/politeelm.github.io/cudm/post-<slug>.svg`
- 配置在各自 `posts.js` 的 `counterPath` 字段，改板块名时记得一起改

> 为什么没用 Moe-counter：`count.getloli.com` 被 Cloudflare 的 JS 挑战挡着，
> 普通 `<img>` 请求只会拿到 403，除非自己在服务器上部署一份。

**不想要这个功能**：把 `app.js` 里 `hydrateCounters()` 的调用删掉即可。

## 八、几个要知道的取舍

**网址是 `#/post/xxx` 这种带井号的。**
好处是不用服务器、不用配置、双击就能跑；代价是搜索引擎收录效果不如独立页面。
个人博客、主要靠 RSS 和熟人传播的话，完全够用。
哪天真在意 SEO 了，再迁到 Astro/Hugo 做预渲染，`posts.js` 里的数据可以直接搬。

**没有评论。**
静态站没有后端。要评论就接 [giscus](https://giscus.app/zh-CN)（基于 GitHub Discussions），
把官方给的 `<script>` 贴到 `app.js` 里文章渲染结束的位置。

**国内访问 `*.github.io` 偏慢。**
同一份文件推到 Cloudflare Pages 即可，免费且通常更快，代码一行都不用改。

**换行、缩进无所谓。**
`app.js` 只认 `posts.js` 的数据结构，格式化随便折腾。

---

## 九、快捷键

| 键 | 作用 |
| --- | --- |
| `/` | 聚焦搜索框 |
| `Esc` | 清空搜索 |
| `T` | 切换深色 / 浅色 |
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
D:\网站\
├── index.html            唯一的页面外壳（内容由 JS 渲染）
├── 404.html              出错页，自动跳回首页
├── feed.xml              RSS 订阅源
├── .nojekyll             告诉 GitHub Pages 别用 Jekyll 处理
├── 新建文章.ps1          一条命令添加新文章
├── assets/
│   ├── css/style.css     全部样式
│   └── js/
│       ├── posts.js      ★ 站点配置 + 所有文章数据（主要改这个）
│       ├── app.js        路由、分页、筛选、搜索、渲染
│       └── main.js       深色模式切换
└── README.md
```

**核心只有一件事：文章不是 HTML 文件，而是 `assets/js/posts.js` 里的一个对象。**

---

## 三、改成你自己的（5 分钟）

### 1. 站点信息

打开 `assets/js/posts.js`，最上面的 `BLOG_CONFIG` 就是全部可配置项：

```js
window.BLOG_CONFIG = {
  title: "L1MA0",        // 站点名（浏览器标签页、页脚）
  tagline: "慢慢写，慢慢记。", // 首页大标题
  intro: "这里存放……",       // 首页那段介绍
  author: "L1MA0",            // 关于页
  email: "steamryy@outlook.com",  // 关于页（投稿邮箱）
  siteUrl: "https://yourname.github.io/blog",
  perPage: 4,                 // ★ 每页显示几篇，改这个就改分页
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
接着打开 `assets/js/posts.js`，把 `content` 里的占位内容换成正文即可（正文就是 HTML）。

如果提示「禁止运行脚本」，改用：

```powershell
powershell -ExecutionPolicy Bypass -File .\新建文章.ps1 -标题 "今天的晚饭"
```

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

### 正文能用的标签

`<h2>` `<h3>` 小标题、`<p>` 段落、`<ul>`/`<ol>` 列表、`<blockquote>` 引用、
`<pre><code>` 代码块、`<strong>` 加粗、`<em>` 斜体、`<img>` 图片、`<table>` 表格——样式都写好了。

图片放到 `assets/images/`（需要自己建），写 `<img src="assets/images/a.jpg" alt="描述">`。

### 增删文章之后

不用改别的地方。分页、标签云、标签数量、上一篇/下一篇全是自动算的。

---

## 五、发布到 GitHub Pages

### 1. 建仓库

GitHub 右上角 **+** → **New repository**：名字填 `blog`，选 **Public**，
不要勾选任何初始化文件，直接 Create。

### 2. 推上去

```powershell
git init
git add -A
git commit -m "first commit"

git config user.name "politeelm"
git config user.email "politeelm@users.noreply.github.com"

git branch -M main
git remote add origin https://github.com/你的用户名/blog.git
git push -u origin main
```

> 推送时 GitHub 要 **Personal Access Token**（Settings → Developer settings →
> Personal access tokens → 勾 `repo`），账号密码早就不支持了。

### 3. 开 Pages

仓库 → **Settings** → **Pages**：Source 选 `Deploy from a branch`，
Branch 选 `main` + `/ (root)`，Save。等 1～2 分钟。

```
仓库名 blog                 →  https://你的用户名.github.io/blog/
仓库名 你的用户名.github.io   →  https://你的用户名.github.io/
```

> 如果是 `/blog/` 这种子路径，只需把 `404.html` 里的 `<base href="/">`
> 改成 `<base href="/blog/">`，其他文件全是相对路径，不用动。

### 4. 以后更新

```powershell
git add -A
git commit -m "新文章：今天的晚饭"
git push
```

---

## 六、几个要知道的取舍

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

## 七、快捷键

| 键 | 作用 |
| --- | --- |
| `/` | 聚焦搜索框 |
| `Esc` | 清空搜索 |
| `T` | 切换深色 / 浅色 |

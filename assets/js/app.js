/* ==========================================================================
   app.js —— 路由、渲染、分页、筛选、搜索
   --------------------------------------------------------------------------
   全部用原生 JS + hash 路由，不需要服务器，双击 index.html 就能跑。
   地址栏的样子：
     #/                    文章列表第 1 页
     #/?page=2             第 2 页
     #/?tag=读书           按标签筛选
     #/?q=笔记&page=1      搜索
     #/post/hello-world    某一篇文章
     #/tags                所有标签
     #/about               关于
   ========================================================================== */

(function () {
  "use strict";

  var cfg = window.BLOG_CONFIG || {};
  var raw = window.BLOG_POSTS || [];
  var perPage = Math.max(1, cfg.perPage || 6);

  var app = document.getElementById("app");

  /* ------------------------------ 工具函数 ------------------------------ */

  function stripTags(html) {
    return String(html || "")
      .replace(/<[^>]*>/g, " ")
      .replace(/\s+/g, " ")
      .trim();
  }

  function escapeHtml(value) {
    return String(value == null ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function fmtDate(iso) {
    var parts = String(iso || "").split("-");
    if (parts.length !== 3) return iso || "";
    return parts[0] + " 年 " + Number(parts[1]) + " 月 " + Number(parts[2]) + " 日";
  }

  function readingTime(plain) {
    var chars = String(plain || "").replace(/\s/g, "").length;
    return { chars: chars, minutes: Math.max(1, Math.round(chars / 400)) };
  }

  /* ------------------------------ 数据准备 ------------------------------ */

  var posts = raw.map(function (post) {
    var plain = stripTags(post.content);
    return {
      slug: post.slug,
      title: post.title || "无标题",
      date: post.date || "",
      tags: post.tags || [],
      summary: post.summary || plain.slice(0, 80),
      content: post.content || "",
      plain: plain
    };
  });

  posts.sort(function (a, b) {
    return String(b.date).localeCompare(String(a.date));
  });

  var allTags = (function () {
    var order = (cfg.tags || []).slice();
    var counts = {};

    order.forEach(function (tag) {
      counts[tag] = 0;
    });

    posts.forEach(function (post) {
      post.tags.forEach(function (tag) {
        if (order.indexOf(tag) === -1) order.push(tag);
        counts[tag] = (counts[tag] || 0) + 1;
      });
    });

    return order.map(function (tag) {
      return { name: tag, count: counts[tag] || 0 };
    });
  })();

  var state = { sort: "desc" };

  /* ------------------------------ hash 路由 ------------------------------ */

  function parseHash() {
    var rawHash = (location.hash || "#/").replace(/^#/, "");
    if (!rawHash) rawHash = "/";

    var qIndex = rawHash.indexOf("?");
    var path = qIndex === -1 ? rawHash : rawHash.slice(0, qIndex);
    var query = qIndex === -1 ? "" : rawHash.slice(qIndex + 1);
    var params = new URLSearchParams(query);
    var segs = path.split("/").filter(Boolean);

    if (segs[0] === "post" && segs[1]) {
      return { view: "post", slug: decodeURIComponent(segs.slice(1).join("/")) };
    }
    if (segs[0] === "tags") return { view: "tags" };
    if (segs[0] === "about") return { view: "about" };

    var page = parseInt(params.get("page") || "1", 10);
    return {
      view: "list",
      page: isNaN(page) || page < 1 ? 1 : page,
      tag: params.get("tag") || "",
      q: params.get("q") || ""
    };
  }

  function listHash(opts) {
    var params = new URLSearchParams();
    if (opts.page && opts.page > 1) params.set("page", String(opts.page));
    if (opts.tag) params.set("tag", opts.tag);
    if (opts.q) params.set("q", opts.q);
    var query = params.toString();
    return "#/" + (query ? "?" + query : "");
  }

  function postHash(slug) {
    return "#/post/" + encodeURIComponent(slug);
  }

  /* ------------------------------ 筛选与分页 ------------------------------ */

  function filterPosts(route) {
    var list = posts.slice();
    if (state.sort === "asc") list.reverse();

    if (route.tag) {
      list = list.filter(function (post) {
        return post.tags.indexOf(route.tag) !== -1;
      });
    }

    var q = String(route.q || "").trim().toLowerCase();
    if (q) {
      list = list.filter(function (post) {
        return (
          (post.title + " " + post.summary + " " + post.plain).toLowerCase().indexOf(q) !== -1
        );
      });
    }

    return list;
  }

  function pageNumbers(current, total) {
    var nums = [];
    var push = function (n) {
      if (n >= 1 && n <= total && nums.indexOf(n) === -1) nums.push(n);
    };

    push(1);
    push(current - 1);
    push(current);
    push(current + 1);
    push(total);
    nums.sort(function (a, b) {
      return a - b;
    });

    var out = [];
    nums.forEach(function (n, i) {
      if (i > 0 && n - nums[i - 1] > 1) out.push("…");
      out.push(n);
    });
    return out;
  }

  /* ------------------------------ 组件片段 ------------------------------ */

  function tagsHtml(tags, current) {
    return tags
      .map(function (tag) {
        var active = tag === current ? " is-active" : "";
        return (
          '<a class="chip' + active + '" href="' + listHash({ tag: tag }) + '">' +
          escapeHtml(tag) +
          "</a>"
        );
      })
      .join("");
  }

  function cardHtml(post) {
    var info = readingTime(post.plain);
    return (
      '<a class="card" href="' + postHash(post.slug) + '">' +
        '<div class="card-top">' +
          '<time datetime="' + escapeHtml(post.date) + '">' + escapeHtml(post.date) + "</time>" +
          '<span class="card-time">' + info.minutes + " 分钟</span>" +
        "</div>" +
        "<h2 class=\"card-title\">" + escapeHtml(post.title) + "</h2>" +
        '<p class="card-summary">' + escapeHtml(post.summary) + "</p>" +
        '<div class="card-foot">' +
          '<span class="card-tags">' +
            post.tags
              .map(function (tag) {
                return '<span class="tag">' + escapeHtml(tag) + "</span>";
              })
              .join("") +
          "</span>" +
          '<span class="card-more">阅读 →</span>' +
        "</div>" +
      "</a>"
    );
  }

  function pagerHtml(route, page, pages) {
    if (pages <= 1) return "";

    var out = ['<nav class="pager" aria-label="分页">'];

    if (page > 1) {
      out.push(
        '<a class="pg pg-arrow" href="' + listHash({ page: page - 1, tag: route.tag, q: route.q }) + '">← 上一页</a>'
      );
    } else {
      out.push('<span class="pg pg-arrow is-disabled">← 上一页</span>');
    }

    pageNumbers(page, pages).forEach(function (n) {
      if (n === "…") {
        out.push('<span class="pg pg-gap">…</span>');
      } else if (n === page) {
        out.push('<span class="pg is-current" aria-current="page">' + n + "</span>");
      } else {
        out.push(
          '<a class="pg" href="' + listHash({ page: n, tag: route.tag, q: route.q }) + '">' + n + "</a>"
        );
      }
    });

    if (page < pages) {
      out.push(
        '<a class="pg pg-arrow" href="' + listHash({ page: page + 1, tag: route.tag, q: route.q }) + '">下一页 →</a>'
      );
    } else {
      out.push('<span class="pg pg-arrow is-disabled">下一页 →</span>');
    }

    out.push("</nav>");
    return out.join("");
  }

  /* ------------------------------ 列表视图 ------------------------------ */

  function resultsHtml(route) {
    var list = filterPosts(route);
    var total = list.length;
    var pages = Math.max(1, Math.ceil(total / perPage));
    var page = Math.min(Math.max(1, route.page), pages);
    var slice = list.slice((page - 1) * perPage, page * perPage);

    var metaBits = ["共 " + total + " 篇"];
    if (route.tag) metaBits.push('标签「' + escapeHtml(route.tag) + "」");
    if (routes_q(route)) metaBits.push("搜索「" + escapeHtml(route.q.trim()) + "」");
    if (total > 0) metaBits.push("第 " + page + " / " + pages + " 页");

    var html =
      '<p class="result-meta">' + metaBits.join(" · ") + "</p>";

    if (!total) {
      if (posts.length === 0 && !route.tag && !routes_q(route)) {
        html +=
          '<div class="empty">' +
          '<p class="empty-title">这里还什么都没有。</p>' +
          '<p class="empty-hint">文章会一篇篇放上来，先看看这个站是干嘛的？</p>' +
          '<a class="btn" href="#/about">关于本站</a>' +
          "</div>";
      } else {
        html +=
          '<div class="empty">' +
          '<p class="empty-title">没有找到相关的文章。</p>' +
          '<p class="empty-hint">换个标签，或者把搜索词删掉试试。</p>' +
          '<a class="btn" href="#/">清除筛选</a>' +
          "</div>";
      }
      return html;
    }

    html +=
      '<div class="cards">' + slice.map(cardHtml).join("") + "</div>" +
      pagerHtml(route, page, pages);

    return html;
  }

  function routes_q(route) {
    return route.q && route.q.trim();
  }

  function renderList(route) {
    var chips = [
      '<a class="chip' + (route.tag ? "" : " is-active") + '" href="' + listHash({ q: route.q }) + '">全部</a>',
      allTags
        .map(function (tag) {
          var active = tag.name === route.tag ? " is-active" : "";
          var count = tag.count > 0 ? '<span class="chip-count">' + tag.count + "</span>" : "";
          return (
            '<a class="chip' + active + '" href="' + listHash({ tag: tag.name }) + '">' +
            escapeHtml(tag.name) +
            count +
            "</a>"
          );
        })
        .join("")
    ].join("");

    app.innerHTML =
      '<section class="hero">' +
        "<h1>" + escapeHtml(cfg.tagline || "") + "</h1>" +
        "<p>" + escapeHtml(cfg.intro || "") + "</p>" +
        (cfg.links && cfg.links.length
          ? '<div class="hero-links">' +
            cfg.links
              .map(function (link) {
                return '<a href="' + escapeHtml(link.href) + '">' + escapeHtml(link.label) + "</a>";
              })
              .join("") +
            "</div>"
          : "") +
      "</section>" +
      '<section class="listing">' +
        '<div class="toolbar">' +
          '<label class="search">' +
            '<span class="search-icon" aria-hidden="true">⌕</span>' +
            '<input id="q" type="search" autocomplete="off" spellcheck="false" placeholder="搜索标题或正文…（按 / 聚焦）" value="' + escapeHtml(route.q) + '">' +
          "</label>" +
          '<button class="sort-btn" id="sortBtn" type="button">' +
            (state.sort === "desc" ? "最新在前 ↓" : "最早在前 ↑") +
          "</button>" +
        "</div>" +
        '<div class="chips" id="chips">' + chips + "</div>" +
        '<div id="results">' + resultsHtml(route) + "</div>" +
      "</section>";

    bindListEvents(route);
  }

  function bindListEvents(route) {
    var input = document.getElementById("q");
    var sortBtn = document.getElementById("sortBtn");
    var results = document.getElementById("results");
    var timer = null;

    if (input) {
      input.addEventListener("input", function () {
        clearTimeout(timer);
        timer = setTimeout(function () {
          var next = { view: "list", page: 1, tag: route.tag, q: input.value.trim() };
          history.replaceState(null, "", listHash(next));
          results.innerHTML = resultsHtml(next);
        }, 160);
      });
    }

    if (sortBtn) {
      sortBtn.addEventListener("click", function () {
        state.sort = state.sort === "desc" ? "asc" : "desc";
        sortBtn.textContent = state.sort === "desc" ? "最新在前 ↓" : "最早在前 ↑";
        results.innerHTML = resultsHtml({ view: "list", page: 1, tag: route.tag, q: route.q });
      });
    }
  }

  /* ------------------------------ 文章视图 ------------------------------ */

  function renderPost(route) {
    var index = -1;
    posts.forEach(function (post, i) {
      if (post.slug === route.slug) index = i;
    });

    if (index === -1) {
      app.innerHTML =
        '<section class="not-found">' +
        '<span class="code">404</span>' +
        '<h1 class="page-title">找不到这篇文章</h1>' +
        '<p class="page-sub">可能是链接抄错了，或者它已经被我删掉。</p>' +
        '<a class="btn" href="#/">回到文章列表</a>' +
        "</section>";
      return;
    }

    var post = posts[index];
    var info = readingTime(post.plain);
    var newer = posts[index - 1];
    var older = posts[index + 1];

    app.innerHTML =
      '<article class="post">' +
        '<a class="back" href="#/">← 返回列表</a>' +
        '<header class="post-header">' +
          '<div class="post-meta">' +
            "<time>" + escapeHtml(fmtDate(post.date)) + "</time>" +
            '<span class="dot"></span>' +
            "<span>约 " + info.minutes + " 分钟 · " + info.chars + " 字</span>" +
          "</div>" +
          '<h1 class="post-title">' + escapeHtml(post.title) + "</h1>" +
          '<p class="post-lead">' + escapeHtml(post.summary) + "</p>" +
          (post.tags.length ? '<div class="chips chips-post">' + tagsHtml(post.tags, "") + "</div>" : "") +
        "</header>" +
        '<div class="prose">' + post.content + "</div>" +
        '<footer class="post-foot">' +
          (newer
            ? '<a class="foot-link" href="' + postHash(newer.slug) + '"><span>← 更新一篇</span>' + escapeHtml(newer.title) + "</a>"
            : '<span class="foot-link is-empty"></span>') +
          (older
            ? '<a class="foot-link is-right" href="' + postHash(older.slug) + '"><span>更早一篇 →</span>' + escapeHtml(older.title) + "</a>"
            : '<span class="foot-link is-empty"></span>') +
        "</footer>" +
      "</article>";
  }

  /* ------------------------------ 标签 / 关于 ------------------------------ */

  function renderTags() {
    app.innerHTML =
      '<section class="page">' +
        '<h1 class="page-title">标签</h1>' +
        '<p class="page-sub">一共 ' + allTags.length + " 个标签，点一下就能筛出相关的文章。</p>" +
        '<div class="tag-cloud">' +
          allTags
            .map(function (tag) {
              return (
                '<a class="tag-pill" href="' + listHash({ tag: tag.name }) + '">' +
                escapeHtml(tag.name) +
                (tag.count > 0
                  ? '<span class="tag-pill-count">' + tag.count + "</span>"
                  : "") +
                "</a>"
              );
            })
            .join("") +
        "</div>" +
      "</section>";
  }

  function renderAbout() {
    var mail = cfg.email || "";

    app.innerHTML =
      '<section class="page">' +
        '<h1 class="page-title">关于</h1>' +
        '<p class="page-sub">此网站收录本人所遇奇异搞笑事件。</p>' +
        '<div class="prose">' +
          "<p>我把遇到的那些事一条条记在这里，免得过几年，连自己都不信真的发生过。</p>" +
          "<p>如果有奇异搞笑事件补充，欢迎投稿至：</p>" +
          '<p class="mail-row"><a class="btn" href="mailto:' + escapeHtml(mail) + '">' + escapeHtml(mail) + "</a></p>" +
          "<p>邮件里写清楚时间、地点、发生了什么就行，不用讲究文笔，能看懂就成。</p>" +
          "<blockquote><p>现实不用讲逻辑，讲逻辑的写不出这种东西。</p></blockquote>" +
        "</div>" +
      "</section>";
  }

  /* ------------------------------ 路由分发 ------------------------------ */

  function setNav(view) {
    var map = { list: "list", post: "list", tags: "tags", about: "about" };
    var active = map[view] || "list";
    var links = document.querySelectorAll("[data-nav]");
    for (var i = 0; i < links.length; i++) {
      if (links[i].getAttribute("data-nav") === active) {
        links[i].setAttribute("aria-current", "page");
      } else {
        links[i].removeAttribute("aria-current");
      }
    }
  }

  function render() {
    var route = parseHash();
    state.sort = state.sort || "desc";

    if (route.view === "post") {
      renderPost(route);
      document.title = (route.slug ? "" : "") + "文章 · " + (cfg.title || "博客");
      var found = posts.filter(function (p) {
        return p.slug === route.slug;
      })[0];
      if (found) document.title = found.title + " · " + (cfg.title || "博客");
    } else if (route.view === "tags") {
      renderTags();
      document.title = "标签 · " + (cfg.title || "博客");
    } else if (route.view === "about") {
      renderAbout();
      document.title = "关于 · " + (cfg.title || "博客");
    } else {
      renderList(route);
      document.title = cfg.tagline || cfg.title || "博客";
    }

    setNav(route.view);
    window.scrollTo(0, 0);
  }

  /* ------------------------------ 滚动相关 ------------------------------ */

  var progress = document.getElementById("progress");
  var toTop = document.getElementById("toTop");

  function onScroll() {
    var doc = document.documentElement;
    var max = doc.scrollHeight - window.innerHeight;
    var ratio = max > 0 ? Math.min(1, window.scrollY / max) : 0;
    if (progress) progress.style.width = (ratio * 100).toFixed(2) + "%";
    if (toTop) toTop.classList.toggle("is-visible", window.scrollY > 480);
  }

  window.addEventListener("scroll", onScroll, { passive: true });

  if (toTop) {
    toTop.addEventListener("click", function () {
      window.scrollTo({ top: 0, behavior: "smooth" });
    });
  }

  /* ------------------------------ 键盘快捷键 ------------------------------ */

  document.addEventListener("keydown", function (event) {
    var target = event.target;
    var typing = target && /^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName);

    if (event.key === "/" && !typing) {
      var input = document.getElementById("q");
      if (input) {
        event.preventDefault();
        input.focus();
      }
    }

    if (event.key === "Escape" && typing) {
      target.value = "";
      target.blur();
      history.replaceState(null, "", "#/");
      render();
    }
  });

  /* ------------------------------ 启动 ------------------------------ */

  window.addEventListener("hashchange", render);

  if (!location.hash) {
    history.replaceState(null, "", "#/");
  }

  render();
  onScroll();
})();

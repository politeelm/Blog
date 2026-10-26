/* 主题切换 + 页脚年份（其余交互在 app.js 里） */
(function () {
  "use strict";

  var root = document.documentElement;
  var toggle = document.querySelector(".theme-toggle");

  function sync() {
    if (!toggle) return;
    var isDark = root.getAttribute("data-theme") === "dark";
    toggle.textContent = isDark ? "☀" : "☾";
    var label = isDark ? "切换到浅色模式" : "切换到深色模式";
    toggle.setAttribute("aria-label", label);
    toggle.setAttribute("title", label + "（快捷键 T）");
  }

  if (toggle) {
    sync();
    toggle.addEventListener("click", function () {
      var next = root.getAttribute("data-theme") === "dark" ? "light" : "dark";
      root.setAttribute("data-theme", next);
      try {
        localStorage.setItem("theme", next);
      } catch (e) {
        /* file:// 或隐私模式下可能不可用 */
      }
      sync();
    });
  }

  var years = document.querySelectorAll("[data-year]");
  for (var i = 0; i < years.length; i++) {
    years[i].textContent = String(new Date().getFullYear());
  }

  document.addEventListener("keydown", function (event) {
    if (event.key !== "t" && event.key !== "T") return;
    if (event.metaKey || event.ctrlKey || event.altKey) return;
    var target = event.target;
    if (target && /^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName)) return;
    if (toggle) toggle.click();
  });
})();

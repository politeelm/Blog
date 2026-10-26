/* ==========================================================================
   站点配置 + 文章数据
   --------------------------------------------------------------------------
   改站点名、作者、每页条数、标签清单：只改下面的 BLOG_CONFIG。
   写新文章：往 BLOG_POSTS 里加一个对象（推荐用「新建文章.ps1」自动加）。
   注意：正文 content 里不要出现反引号 ` 和 ${ 两个符号。
   ========================================================================== */

window.BLOG_CONFIG = {
  title: "L1MA0",
  tagline: "L1MA0的个人网页",
  intro: "如果我冒犯到了你，那我说的就是你，憋着",
  author: "L1MA0",
  email: "steamryy@outlook.com",
  siteUrl: "https://politeelm.github.io/Blog",
  perPage: 4,

  /* 标签清单：这里写了就会出现在筛选栏和标签页，哪怕暂时没有文章。
     顺序就是显示顺序；文章里用了这里没有的标签，会自动补在后面。 */
  tags: [
    "奇异人士",
    "童站神人",
    "后门高手",
    "洗脑大神",
    "我草恶俗",
    "挂人天王",
    "devlog",
    "release"
  ],

  links: [
    { label: "RSS", href: "feed.xml" },
    { label: "GitHub", href: "https://github.com/politeelm/Blog" }
  ]
};

window.BLOG_POSTS = [
  /* POSTS:START */
  /* POSTS:END */
];

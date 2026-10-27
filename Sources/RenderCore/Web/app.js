(() => {
  "use strict";

  const ASSET = "glancedown://asset/";
  const content = document.getElementById("content");
  const darkScheme = window.matchMedia("(prefers-color-scheme: dark)");
  const pending = new Map();

  function loadScript(path) {
    if (!pending.has(path)) {
      pending.set(path, new Promise((resolve, reject) => {
        const script = document.createElement("script");
        script.src = ASSET + path;
        script.onload = resolve;
        script.onerror = () => reject(new Error("failed to load " + path));
        document.head.appendChild(script);
      }));
    }
    return pending.get(path);
  }

  function loadStyle(path) {
    if (!document.querySelector(`link[data-gd="${path}"]`)) {
      const link = document.createElement("link");
      link.rel = "stylesheet";
      link.href = ASSET + path;
      link.dataset.gd = path;
      document.head.appendChild(link);
    }
  }

  function post(message) {
    const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.glancedown;
    if (handler) handler.postMessage(message);
  }

  // ---- Code blocks -------------------------------------------------------

  function languageOf(code) {
    const match = /(?:^|\s)language-([\w+#.-]+)/.exec(code.className);
    return match ? match[1].toLowerCase() : null;
  }

  function highlightCode(root) {
    if (!window.hljs) return;
    root.querySelectorAll("pre > code").forEach((code) => {
      const language = languageOf(code);
      if (language && hljs.getLanguage(language)) {
        hljs.highlightElement(code);
      }
    });
  }

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text);
    }
    const area = document.createElement("textarea");
    area.value = text;
    area.style.position = "fixed";
    area.style.opacity = "0";
    document.body.appendChild(area);
    area.select();
    document.execCommand("copy");
    area.remove();
    return Promise.resolve();
  }

  function addCopyButtons(root) {
    root.querySelectorAll("pre").forEach((pre) => {
      if (pre.querySelector(".gd-copy")) return;
      const button = document.createElement("button");
      button.className = "gd-copy";
      button.type = "button";
      button.textContent = "Copy";
      button.addEventListener("click", () => {
        const code = pre.querySelector("code");
        copyText(code ? code.innerText : pre.innerText).then(() => {
          button.textContent = "Copied";
          setTimeout(() => (button.textContent = "Copy"), 1200);
        });
      });
      pre.appendChild(button);
    });
  }

  // ---- Mermaid -----------------------------------------------------------

  async function renderMermaid(root) {
    const blocks = [...root.querySelectorAll("pre > code.language-mermaid")];
    if (blocks.length === 0) return;
    const nodes = blocks.map((code) => {
      const container = document.createElement("div");
      container.className = "gd-mermaid";
      container.textContent = code.textContent;
      code.parentElement.replaceWith(container);
      return container;
    });
    try {
      await loadScript("vendor/mermaid.min.js");
      mermaid.initialize({
        startOnLoad: false,
        securityLevel: "strict",
        theme: darkScheme.matches ? "dark" : "default",
      });
      await mermaid.run({ nodes, suppressErrors: true });
    } catch (error) {
      console.error(error);
    }
  }

  // ---- Math --------------------------------------------------------------

  // $$display$$, or inline $x$ that does not start/end with a space and is not followed by a digit (GitHub rules).
  const MATH_PATTERN = /\$\$([\s\S]+?)\$\$|\$(?=[^\s$])([^$\n]*?[^\s$\\])\$(?!\d)/g;
  const SKIPPED_TAGS = new Set(["CODE", "PRE", "SCRIPT", "STYLE", "TEXTAREA", "KBD"]);

  function mathTextNodes(root) {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode(node) {
        for (let parent = node.parentElement; parent && parent !== root; parent = parent.parentElement) {
          if (SKIPPED_TAGS.has(parent.tagName)) return NodeFilter.FILTER_REJECT;
        }
        return node.nodeValue.includes("$") ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_SKIP;
      },
    });
    const nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);
    return nodes;
  }

  function findMath(root) {
    const blocks = [...root.querySelectorAll("pre > code.language-math")];
    const inline = mathTextNodes(root).filter((node) => {
      MATH_PATTERN.lastIndex = 0;
      return MATH_PATTERN.test(node.nodeValue);
    });
    return { blocks, inline };
  }

  function renderMathInTextNode(node) {
    const text = node.nodeValue;
    const fragment = document.createDocumentFragment();
    let last = 0;
    MATH_PATTERN.lastIndex = 0;
    for (let match; (match = MATH_PATTERN.exec(text)); ) {
      fragment.appendChild(document.createTextNode(text.slice(last, match.index)));
      const display = match[1] !== undefined;
      const element = document.createElement(display ? "div" : "span");
      if (display) element.className = "gd-math-display";
      katex.render(display ? match[1] : match[2], element, { displayMode: display, throwOnError: false });
      fragment.appendChild(element);
      last = match.index + match[0].length;
    }
    fragment.appendChild(document.createTextNode(text.slice(last)));
    node.replaceWith(fragment);
  }

  async function renderMath(root) {
    const { blocks, inline } = findMath(root);
    if (blocks.length === 0 && inline.length === 0) return;
    try {
      loadStyle("vendor/katex/katex.min.css");
      await loadScript("vendor/katex/katex.min.js");
      blocks.forEach((code) => {
        const container = document.createElement("div");
        container.className = "gd-math-display";
        katex.render(code.textContent, container, { displayMode: true, throwOnError: false });
        code.parentElement.replaceWith(container);
      });
      inline.forEach(renderMathInTextNode);
    } catch (error) {
      console.error(error);
    }
  }

  // ---- Outline -----------------------------------------------------------

  function slugify(text) {
    return text
      .trim()
      .toLowerCase()
      .replace(/[^\p{L}\p{N}\s_-]/gu, "")
      .replace(/\s/g, "-");
  }

  function headings() {
    return [...content.querySelectorAll("h1, h2, h3, h4, h5, h6")];
  }

  function buildOutline() {
    const used = new Map();
    const items = headings().map((heading) => {
      const base = slugify(heading.textContent) || "section";
      const count = used.get(base) || 0;
      used.set(base, count + 1);
      heading.id = count === 0 ? base : `${base}-${count}`;
      return { id: heading.id, level: Number(heading.tagName[1]), title: heading.textContent.trim() };
    });
    post({ type: "outline", items });
  }

  let lastActive;
  function reportActiveHeading() {
    let active = null;
    for (const heading of headings()) {
      if (heading.getBoundingClientRect().top > 80) break;
      active = heading.id;
    }
    if (active !== lastActive) {
      lastActive = active;
      post({ type: "active", id: active });
    }
  }

  let scrollScheduled = false;
  window.addEventListener("scroll", () => {
    if (scrollScheduled) return;
    scrollScheduled = true;
    requestAnimationFrame(() => {
      scrollScheduled = false;
      reportActiveHeading();
    });
  }, { passive: true });

  // ---- Entry points ------------------------------------------------------

  async function decorate() {
    highlightCode(content);
    buildOutline();
    await Promise.all([renderMermaid(content), renderMath(content)]);
    addCopyButtons(content);
    lastActive = undefined;
    reportActiveHeading();
  }

  window.glancedown = {
    update(html) {
      const scrollY = window.scrollY;
      content.innerHTML = html;
      window.scrollTo(0, scrollY);
      return decorate().then(() => window.scrollTo(0, scrollY));
    },
    scrollToHeading(id) {
      const target = document.getElementById(id);
      if (target) target.scrollIntoView({ block: "start" });
    },
    // Editor scroll sync: index -1 means "above the first heading".
    scrollToHeadingIndex(index) {
      const target = headings()[index];
      if (target) {
        window.scrollTo(0, target.getBoundingClientRect().top + window.scrollY - 8);
      } else if (index < 0) {
        window.scrollTo(0, 0);
      }
    },
  };

  darkScheme.addEventListener("change", () => {
    if (content.querySelector(".gd-mermaid")) {
      // Mermaid bakes colors into the SVG, so re-render from source.
      post({ type: "reload" });
    }
  });

  decorate();
})();

(function () {
  "use strict";

  var comments = [];
  var fileHandle = null;
  var meta = {};

  function loadMeta() {
    var el = document.getElementById("review-meta");
    if (!el) return {};
    try {
      return JSON.parse(el.textContent);
    } catch (e) {
      return {};
    }
  }

  function loadComments() {
    var el = document.getElementById("review-comments");
    if (!el) return [];
    try {
      var data = JSON.parse(el.textContent);
      return Array.isArray(data) ? data : [];
    } catch (e) {
      return [];
    }
  }

  function loadMarkdown() {
    var el = document.getElementById("review-source");
    if (!el) return "";
    try {
      var data = JSON.parse(el.textContent);
      return typeof data === "string" ? data : data.markdown || "";
    } catch (e) {
      return el.textContent || "";
    }
  }

  function escapeHtml(text) {
    var div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }

  function getSectionLabel(node) {
    var el = node;
    while (el && el !== document.getElementById("review-content")) {
      if (el.tagName === "H1" || el.tagName === "H2" || el.tagName === "H3") {
        return el.textContent.trim();
      }
      el = el.parentElement;
    }
    return "Review";
  }

  function parseVerdictClass(text) {
    var lower = text.toLowerCase();
    if (lower.indexOf("approve") === 0 && lower.indexOf("request") === -1) return "approve";
    if (lower.indexOf("request changes") === 0 || lower.indexOf("request change") === 0) return "request";
    if (lower.indexOf("blocked") === 0) return "blocked";
    return "neutral";
  }

  var SEVERITY_HEADING_RE = /^(.*?)\s*[—–-]\s*Severity:\s*(High|Med(?:ium)?|Low)\s*$/i;

  function normalizeSeverity(word) {
    var lower = (word || "").toLowerCase();
    if (lower === "high") return { cls: "high", label: "High" };
    if (lower === "low") return { cls: "low", label: "Low" };
    if (lower.indexOf("med") === 0) return { cls: "med", label: "Medium" };
    return null;
  }

  function enhanceFindings(container) {
    var headings = container.querySelectorAll("h3");
    headings.forEach(function (h3) {
      var headingText = h3.textContent.trim();
      if (!/^F\d+\s*[—–-]/.test(headingText)) return;

      var card = document.createElement("div");
      card.className = "finding-card";
      h3.parentNode.insertBefore(card, h3);
      card.appendChild(h3);

      // Preferred: "F1 — Title — Severity: High" on the heading itself.
      var severity = null;
      var match = headingText.match(SEVERITY_HEADING_RE);
      if (match) {
        severity = normalizeSeverity(match[2]);
        h3.textContent = match[1];
      }

      // Fallback for older reports that put "**Severity:** High" in the body.
      if (!severity) {
        var sibling = h3.nextElementSibling;
        while (sibling && sibling.tagName !== "H3" && sibling.tagName !== "H2" && sibling.tagName !== "H1") {
          var text = sibling.textContent || "";
          var bodyMatch = text.match(/Severity:\s*(High|Med(?:ium)?|Low)/i);
          if (bodyMatch) {
            severity = normalizeSeverity(bodyMatch[1]);
            break;
          }
          sibling = sibling.nextElementSibling;
        }
      }

      var badge = document.createElement("span");
      badge.className = "severity-badge severity-" + (severity ? severity.cls : "unknown");
      badge.textContent = "Severity: " + (severity ? severity.label : "Unknown");
      h3.appendChild(badge);

      // Body siblings still need to be moved into the card even when severity
      // was found on the heading (the loop above only walked them to search).
      var node = h3.nextElementSibling;
      while (node && node.tagName !== "H3" && node.tagName !== "H2" && node.tagName !== "H1") {
        var nextNode = node.nextElementSibling;
        card.appendChild(node);
        node = nextNode;
      }
    });
  }

  function enhanceVerdict(container) {
    var headings = container.querySelectorAll("h2");
    headings.forEach(function (h2) {
      if (h2.textContent.trim() !== "Verdict") return;
      var p = h2.nextElementSibling;
      if (!p || p.tagName !== "P") return;

      var banner = document.createElement("div");
      banner.className = "verdict-banner " + parseVerdictClass(p.textContent);
      banner.textContent = p.textContent;
      p.parentNode.replaceChild(banner, p);
    });
  }

  function renderMarkdown() {
    var container = document.getElementById("review-content");
    if (!container) return;

    if (container.getAttribute("data-prerendered") === "true" || container.innerHTML.trim()) {
      enhanceFindings(container);
      enhanceVerdict(container);
      return;
    }

    var md = loadMarkdown();
    if (!md) {
      container.innerHTML = '<p class="empty-comments">Review content failed to load.</p>';
      return;
    }

    if (!window.marked) {
      container.innerHTML = '<p class="empty-comments">Markdown renderer unavailable — regenerate with Write-PrReviewHtml.ps1.</p>';
      return;
    }

    if (typeof marked.setOptions === "function") {
      marked.setOptions({ gfm: true, breaks: true });
    } else if (typeof marked.use === "function") {
      marked.use({ gfm: true, breaks: true });
    }

    var html = typeof marked.parse === "function" ? marked.parse(md) : marked(md);
    container.innerHTML = html;

    enhanceFindings(container);
    enhanceVerdict(container);
  }

  function renderCommentList() {
    var list = document.getElementById("comment-list");
    if (!list) return;

    list.innerHTML = "";
    if (comments.length === 0) {
      list.innerHTML = '<p class="empty-comments">Select text in the review and click &ldquo;Add comment&rdquo;.</p>';
      return;
    }

    comments.forEach(function (c, index) {
      var card = document.createElement("div");
      card.className = "comment-card";
      card.dataset.index = String(index);

      card.innerHTML =
        '<div class="section-label">' +
        escapeHtml(c.section || "Review") +
        "</div>" +
        "<blockquote>" +
        escapeHtml(c.quoted || "") +
        "</blockquote>" +
        '<textarea data-index="' +
        index +
        '" placeholder="Your comment…">' +
        escapeHtml(c.text || "") +
        "</textarea>" +
        '<div class="comment-meta">' +
        escapeHtml(c.created || "") +
        "</div>" +
        '<div class="card-actions">' +
        '<button type="button" class="copy-one" data-index="' +
        index +
        '">Copy</button>' +
        '<button type="button" class="danger delete-one" data-index="' +
        index +
        '">Delete</button>' +
        "</div>";

      list.appendChild(card);
    });

    list.querySelectorAll("textarea").forEach(function (ta) {
      ta.addEventListener("input", function () {
        var idx = parseInt(ta.dataset.index, 10);
        if (comments[idx]) comments[idx].text = ta.value;
      });
    });

    list.querySelectorAll(".copy-one").forEach(function (btn) {
      btn.addEventListener("click", function () {
        copyComment(parseInt(btn.dataset.index, 10));
      });
    });

    list.querySelectorAll(".delete-one").forEach(function (btn) {
      btn.addEventListener("click", function () {
        comments.splice(parseInt(btn.dataset.index, 10), 1);
        renderCommentList();
      });
    });
  }

  function formatComment(c) {
    return (
      "---\n" +
      "Section: " +
      (c.section || "Review") +
      "\n" +
      'Quoted: "' +
      (c.quoted || "").replace(/"/g, '\\"') +
      '"\n' +
      "Comment: " +
      (c.text || "") +
      "\n" +
      "---"
    );
  }

  function copyComment(index) {
    var c = comments[index];
    if (!c) return;
    navigator.clipboard.writeText(formatComment(c)).then(function () {
      showToast("Comment copied to clipboard");
    });
  }

  function copyAllComments() {
    if (comments.length === 0) {
      showToast("No comments to copy");
      return;
    }
    var text = comments.map(formatComment).join("\n\n");
    navigator.clipboard.writeText(text).then(function () {
      showToast("All comments copied to clipboard");
    });
  }

  function showToast(message) {
    var existing = document.querySelector(".toast");
    if (existing) existing.remove();

    var toast = document.createElement("div");
    toast.className = "toast";
    toast.textContent = message;
    document.body.appendChild(toast);
    setTimeout(function () {
      toast.remove();
    }, 3500);
  }

  function hidePopup() {
    var popup = document.getElementById("comment-popup");
    if (popup) popup.remove();
  }

  function showCommentPopup(x, y, selectedText, section) {
    hidePopup();

    var popup = document.createElement("div");
    popup.id = "comment-popup";
    popup.className = "comment-popup";
    popup.style.left = x + "px";
    popup.style.top = y + "px";

    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = "primary";
    btn.textContent = "Add comment";
    btn.addEventListener("click", function () {
      comments.push({
        id: "c-" + Date.now(),
        section: section,
        quoted: selectedText,
        text: "",
        created: new Date().toISOString(),
      });
      renderCommentList();
      hidePopup();
      showToast("Comment added — edit in sidebar, then Save");
    });

    popup.appendChild(btn);
    document.body.appendChild(popup);
  }

  function setupSelection() {
    var content = document.getElementById("review-content");
    if (!content) return;

    content.addEventListener("mouseup", function () {
      setTimeout(function () {
        var sel = window.getSelection();
        if (!sel || sel.isCollapsed || !sel.toString().trim()) {
          hidePopup();
          return;
        }

        var range = sel.getRangeAt(0);
        if (!content.contains(range.commonAncestorContainer)) {
          hidePopup();
          return;
        }

        var text = sel.toString().trim();
        if (text.length < 2) {
          hidePopup();
          return;
        }

        var rect = range.getBoundingClientRect();
        var section = getSectionLabel(range.commonAncestorContainer.nodeType === 3 ? range.commonAncestorContainer.parentElement : range.commonAncestorContainer);
        showCommentPopup(rect.left + rect.width / 2 - 50, rect.bottom + window.scrollY + 6, text, section);
      }, 10);
    });

    document.addEventListener("mousedown", function (e) {
      if (e.target.closest("#comment-popup")) return;
      if (e.target.closest(".comment-card")) return;
    });
  }

  function buildFullHtml() {
    var template = document.documentElement.outerHTML;

    var mdJson = JSON.stringify(loadMarkdown());
    var commentsJson = JSON.stringify(comments, null, 2);
    var endScript = "<" + "/script>";
    var openSource = "<" + 'script type="application/json" id="review-source">';
    var openComments = "<" + 'script type="application/json" id="review-comments">';

    var sourceRe = new RegExp('<script type="application/json" id="review-source">[\\s\\S]*?' + endScript.replace(/\//g, "\\/"));
    var commentsRe = new RegExp('<script type="application/json" id="review-comments">[\\s\\S]*?' + endScript.replace(/\//g, "\\/"));

    template = template.replace(
      sourceRe,
      openSource + mdJson.replace(/<\//g, "<\\/") + endScript
    );

    template = template.replace(
      commentsRe,
      openComments + commentsJson.replace(/<\//g, "<\\/") + endScript
    );

    return "<!DOCTYPE html>\n" + template;
  }

  async function saveToFile() {
    var html = buildFullHtml();
    var blob = new Blob([html], { type: "text/html;charset=utf-8" });
    var filename = meta.suggestedFilename || "pr-review.html";

    try {
      if (fileHandle) {
        var writable = await fileHandle.createWritable();
        await writable.write(blob);
        await writable.close();
        showToast("Saved to " + (meta.outputPath || filename));
        return;
      }

      if (window.showSaveFilePicker) {
        fileHandle = await window.showSaveFilePicker({
          suggestedName: filename,
          types: [{ description: "HTML", accept: { "text/html": [".html"] } }],
        });
        var w = await fileHandle.createWritable();
        await w.write(blob);
        await w.close();
        showToast("Saved — replace original at: " + (meta.outputPath || filename));
        return;
      }
    } catch (e) {
      if (e.name === "AbortError") return;
    }

    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
    showToast("Downloaded updated HTML — replace file at: " + (meta.outputPath || filename));
  }

  function setupToolbar() {
    document.getElementById("btn-save")?.addEventListener("click", saveToFile);
    document.getElementById("btn-copy-all")?.addEventListener("click", copyAllComments);
    document.getElementById("btn-clear")?.addEventListener("click", function () {
      if (comments.length && confirm("Delete all comments?")) {
        comments = [];
        renderCommentList();
      }
    });
  }

  function init() {
    meta = loadMeta();
    comments = loadComments();
    renderMarkdown();
    renderCommentList();
    setupSelection();
    setupToolbar();

    document.title = meta.title || "PR Review";
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();

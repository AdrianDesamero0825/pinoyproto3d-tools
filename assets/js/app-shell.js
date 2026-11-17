(() => {
  const frame = document.getElementById("toolFrame");
  const home = document.getElementById("homeView");
  const links = [...document.querySelectorAll("[data-tool]")];

  // Add future workspace pages here; the shell and sidebar remain the only shared layout.
  const tools = {
    dashboard: "tools/dashboard.html",
    "customer-tracker": "tools/customer-tracker.html",
    "customer-feedback": "tools/customer-feedback.html",
    "quotation-maker": "tools/quotation-maker.html",
    "bambu-studio": "tools/bambu-studio.html",
    "new-tool": "tools/new-tool.html",
    "quotation-records": "tools/quotation-records.html",
    "transaction-records": "tools/transaction-records.html",
  };

  function setActiveTool(key) {
    for (const link of links) {
      if (link.matches(".tool-link")) {
        if (link.dataset.tool === key) link.setAttribute("aria-current", "page");
        else link.removeAttribute("aria-current");
      }
    }
  }

  function openTool(key) {
    const path = tools[key];
    if (!path) return;
    home.hidden = true;
    frame.hidden = false;
    setActiveTool(key);
    if (frame.dataset.loadedPath !== path) {
      frame.dataset.loadedPath = path;
      frame.src = path;
    }
    history.replaceState(null, "", `#${encodeURIComponent(key)}`);
  }

  function showHome() {
    frame.hidden = true;
    home.hidden = false;
    setActiveTool("");
    history.replaceState(null, "", location.pathname + location.search);
  }

  for (const link of links) {
    link.addEventListener("click", (event) => {
      if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      event.preventDefault();
      openTool(link.dataset.tool);
    });
  }

  document.querySelector("[data-home-link]").addEventListener("click", (event) => {
    event.preventDefault();
    showHome();
  });

  frame.addEventListener("load", () => {
    try {
      const doc = frame.contentDocument;
      if (!doc || doc.getElementById("workspace-embedded-overrides")) return;
      const style = doc.createElement("style");
      style.id = "workspace-embedded-overrides";
      style.textContent = `
        html, body { min-width:0 !important; min-height:100% !important; overflow-x:hidden !important; }
        body { margin:0 !important; }
        nav[aria-label="Tool navigation"] { display:none !important; }
        .app, .tool-app { display:block !important; min-height:100% !important; }
        .app > main, .app > .content, .tool-app > .tool-page {
          grid-column:auto !important; width:100% !important; max-width:none !important;
          min-height:100vh; margin:0 !important; padding:clamp(20px, 3vw, 40px) clamp(16px, 3vw, 42px) 48px !important;
        }
        .studio-main { width:100% !important; max-width:none !important; margin:0 !important; padding:clamp(20px, 3vw, 40px) clamp(16px, 3vw, 42px) 48px !important; }
      `;
      doc.head.append(style);
    } catch (error) {
      console.error("Could not apply the shared workspace layout to this page.", error);
    }
  });

  const initialKey = decodeURIComponent(location.hash.slice(1));
  if (tools[initialKey]) openTool(initialKey);
})();

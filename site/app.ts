// This TypeScript source intentionally uses browser-standard JavaScript syntax.
// build-site.mjs copies it deterministically to app.js without a package dependency.
(() => {
  "use strict";

  const features = Array.isArray(window.MATERIAL_PHONE_FEATURES) ? window.MATERIAL_PHONE_FEATURES : [];
  const buildMetadata = window.MATERIAL_PHONE_BUILD || { commit: null, generatedAt: null, docsBase: "../docs/" };
  const storageKey = "material-phone-site-preferences-v1";
  const defaultPreferences = Object.freeze({ theme: "light", language: "en", enFunny: 5, yueFunny: 5 });
  const allowedThemes = new Set(["light", "dark", "contrast"]);
  const allowedLanguages = new Set(["en", "yue", "both"]);
  const pageMeta = {
    home: ["Home", "Product overview and boundaries"],
    features: ["Features", "Desktop and web coverage ledger"],
    docs: ["Documentation", "Behavior, configuration, failures, security, and verification"],
    download: ["Download", "Evidence-gated Windows delivery"],
    status: ["Status", "Current repository evidence"],
    settings: ["Settings", "Local visitor preferences"]
  };
  const copy = {
    en: {
      boundary: [
        "This website provides documentation, download status, settings, and links. It is not the calling runtime and does not place or receive calls.",
        "This website provides documentation, download status, settings, and links. It is not the calling runtime and does not place or receive calls.",
        "This website keeps documentation, download status, settings, and links together. It is not the calling runtime and does not place or receive calls.",
        "This website keeps documentation, download status, settings, and links together. The calls stay in the installed runtime, where phones are less decorative.",
        "This website keeps documentation, download status, settings, and links together. It cannot place or receive calls; the phone card has stage presence, not a phone line."
      ],
      saved: ["Site preference saved locally.", "Site preference saved locally.", "Site preference saved locally.", "Site preference saved locally; no suitcase required.", "Site preference saved locally. It has unpacked its tiny suitcase."],
      reset: ["Site preferences reset to shipped defaults.", "Site preferences reset to shipped defaults.", "Site preferences reset to shipped defaults.", "Site preferences reset; the defaults are back at their desks.", "Site preferences reset; the defaults marched back in looking suspiciously organized."]
    },
    yue: {
      boundary: [
        "呢個網站提供文件、下載狀態、設定同連結；唔係通話程式，唔會打出或接聽電話。",
        "呢個網站提供文件、下載狀態、設定同連結；唔係通話程式，唔會打出或接聽電話。",
        "呢個網站集中放文件、下載狀態、設定同連結；唔係通話程式，唔會打出或接聽電話。",
        "呢個網站集中放文件、下載狀態、設定同連結；通話要交返畀已安裝程式處理。",
        "呢個網站集中放文件、下載狀態、設定同連結；唔會打出或接聽電話，電話卡得個樣但冇電話線。"
      ],
      saved: ["網站偏好已儲存喺本機。", "網站偏好已儲存喺本機。", "網站偏好已留喺本機。", "網站偏好已留喺本機，唔使執行李。", "網站偏好已留喺本機，細細個行李篋都收好埋。"],
      reset: ["網站偏好已還原至預設值。", "網站偏好已還原至預設值。", "網站偏好已還原。", "網站偏好已還原，預設值返晒位。", "網站偏好已還原，預設值排隊企到直一直。"]
    }
  };
  const docs = [
    ["Site architecture", "site/architecture.md", "Static boundaries, local assets, navigation, and build flow."],
    ["Navigation and command palette", "site/navigation.md", "Tabs, responsive rail, keyboard behavior, palette, and focus return."],
    ["Settings and localization", "site/settings.md", "Theme, language modes, funny levels, persistence, reset, and privacy."],
    ["Regex builder", "site/regex-builder.md", "JavaScript dialect, flags, guided tokens, validation, safety bounds, and search synchronization."],
    ["Feature inventory", "features/inventory.md", "Desktop and web status semantics, explicit exclusions, evidence, and maintenance."],
    ["Status and downloads", "delivery/status-downloads.md", "Evidence cards, disabled download behavior, release manifest requirements, and failure states."],
    ["Accessibility", "quality/accessibility.md", "Keyboard routes, semantics, focus, contrast, motion, layout, and verification."],
    ["Privacy and security", "quality/privacy-security.md", "Local storage, network boundary, secret exclusions, and public prose safety."],
    ["Provenance", "project/provenance.md", "Upstream relationship, authored surface scope, and evidence boundaries."]
  ];
  const paletteCommands = [
    ...Object.entries(pageMeta).map(([id, [label, description]]) => ({ id, label, description, type: "page" })),
    { id: "theme-setting", label: "Change theme", description: "Open the exact theme control", type: "setting" },
    { id: "language-setting", label: "Change language presentation", description: "Open the exact language control", type: "setting" },
    { id: "en-funny", label: "English funny level", description: "Open the English voice slider", type: "setting" },
    { id: "yue-funny", label: "Cantonese funny level", description: "Open the Cantonese voice slider", type: "setting" },
    { id: "regex-toggle", label: "Open regex builder", description: "Build a settings-search expression", type: "setting" },
    { id: "vocabulary-upload", label: "Personal vocabulary file", description: "Focus the visible local file control", type: "setting" }
  ];

  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
  let preferenceStatusMessage = "Local preference storage has not reported a problem.";
  let preferenceStorageAvailable = true;

  function setPreferenceStatus(message) {
    preferenceStatusMessage = message;
    const region = $("#preference-status");
    if (region) region.textContent = message;
  }

  function normalizePreferences(candidate) {
    const source = candidate && typeof candidate === "object" && !Array.isArray(candidate) ? candidate : {};
    return {
      theme: allowedThemes.has(source.theme) ? source.theme : defaultPreferences.theme,
      language: allowedLanguages.has(source.language) ? source.language : defaultPreferences.language,
      enFunny: Number.isInteger(source.enFunny) && source.enFunny >= 1 && source.enFunny <= 5 ? source.enFunny : defaultPreferences.enFunny,
      yueFunny: Number.isInteger(source.yueFunny) && source.yueFunny >= 1 && source.yueFunny <= 5 ? source.yueFunny : defaultPreferences.yueFunny
    };
  }

  function loadPreferences() {
    try {
      const stored = localStorage.getItem(storageKey);
      if (stored === null) return { ...defaultPreferences };
      try { return normalizePreferences(JSON.parse(stored)); }
      catch { setPreferenceStatus("Stored preferences were invalid, so shipped defaults are active."); return { ...defaultPreferences }; }
    } catch {
      preferenceStorageAvailable = false;
      setPreferenceStatus("Local preference storage is unavailable. Changes work for this page only and will not survive a reload.");
      return { ...defaultPreferences };
    }
  }
  let preferences = loadPreferences();
  let settingsRegex = null;
  const mobileNavigation = window.matchMedia("(max-width: 900px)");

  function savePreferences(announce = true) {
    preferences = normalizePreferences(preferences);
    try {
      localStorage.setItem(storageKey, JSON.stringify(preferences));
      preferenceStorageAvailable = true;
      setPreferenceStatus("Preferences are stored locally in this browser.");
      if (announce) showToast(localized("saved"));
      return true;
    } catch {
      preferenceStorageAvailable = false;
      setPreferenceStatus("Local preference storage refused the update. The visible change is temporary and will not survive a reload.");
      return false;
    }
  }

  function localized(key) {
    const enValue = copy.en[key][preferences.enFunny - 1] || copy.en[key][0];
    const yueValue = copy.yue[key][preferences.yueFunny - 1] || copy.yue[key][0];
    if (preferences.language === "both") return `${enValue} / ${yueValue}`;
    return preferences.language === "yue" ? yueValue : enValue;
  }

  function applyPreferences() {
    preferences = normalizePreferences(preferences);
    document.documentElement.dataset.theme = preferences.theme;
    document.documentElement.lang = preferences.language === "yue" ? "yue-Hant-HK" : "en";
    $("#theme-setting").value = preferences.theme;
    $("#language-setting").value = preferences.language;
    $("#en-funny").value = String(preferences.enFunny);
    $("#yue-funny").value = String(preferences.yueFunny);
    $("#en-funny-output").textContent = String(preferences.enFunny);
    $("#yue-funny-output").textContent = String(preferences.yueFunny);
    $("[data-copy='boundary']").textContent = localized("boundary");
    setPreferenceStatus(preferenceStatusMessage);
  }

  function showToast(message) {
    const toast = document.createElement("div");
    toast.className = "toast";
    toast.textContent = message;
    $("#toast-region").append(toast);
    window.setTimeout(() => toast.remove(), 4200);
  }

  function setDrawer(open, returnFocus = false) {
    const rail = $("#rail");
    const opener = $("#open-nav");
    if (!mobileNavigation.matches) {
      rail.classList.remove("open");
      rail.removeAttribute("inert");
      rail.setAttribute("aria-hidden", "false");
      opener.setAttribute("aria-expanded", "false");
      return;
    }
    rail.classList.toggle("open", open);
    rail.toggleAttribute("inert", !open);
    rail.setAttribute("aria-hidden", String(!open));
    opener.setAttribute("aria-expanded", String(open));
    if (open) $("#close-nav").focus();
    else if (returnFocus) opener.focus();
  }

  function activatePage(page, focusTarget = true) {
    if (!pageMeta[page]) return;
    $$(".tabs [role='tab']").forEach((tab) => {
      const selected = tab.dataset.tab === page;
      tab.setAttribute("aria-selected", String(selected));
      tab.tabIndex = selected ? 0 : -1;
    });
    $$(".tab-panel").forEach((panel) => {
      const selected = panel.dataset.page === page;
      panel.hidden = !selected;
      panel.classList.toggle("active", selected);
    });
    $("#page-title").textContent = pageMeta[page][0];
    $("#page-subtitle").textContent = pageMeta[page][1];
    setDrawer(false, false);
    history.replaceState(null, "", `#${page}`);
    if (focusTarget) $("#main").focus();
  }

  function statusChip(status) {
    const label = status.charAt(0).toUpperCase() + status.slice(1);
    return `<span class="status-chip" data-state="${status}">${label}</span>`;
  }

  function renderFeatureInventory() {
    const query = $("#feature-search").value.trim().toLocaleLowerCase();
    const surface = $("#surface-filter").value;
    const status = $("#status-filter").value;
    const filtered = features.filter((feature) => {
      const haystack = `${feature.name} ${feature.desktop} ${feature.web} ${feature.evidence}`.toLocaleLowerCase();
      const queryMatch = !query || haystack.includes(query);
      const surfaceMatch = surface === "all" || (surface === "desktop" ? feature.desktop !== "excluded" : feature.web !== "excluded");
      const statusMatch = status === "all" || feature.desktop === status || feature.web === status;
      return queryMatch && surfaceMatch && statusMatch;
    });
    $("#feature-table").innerHTML = filtered.map((feature) => `<tr><th scope="row">${escapeHtml(feature.name)}</th><td>${statusChip(feature.desktop)}</td><td>${statusChip(feature.web)}</td><td>${escapeHtml(feature.evidence)}</td></tr>`).join("");
    $("#feature-result-count").textContent = `${filtered.length} of ${features.length} contracts shown.`;
  }

  function escapeHtml(value) {
    return String(value).replace(/[&<>"']/g, (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#039;" })[character]);
  }

  function renderDocs() {
    const docsBase = typeof buildMetadata.docsBase === "string" && /^(?:\.\.\/)?docs\/$/.test(buildMetadata.docsBase) ? buildMetadata.docsBase : "../docs/";
    $("#docs-grid").innerHTML = docs.map(([title, path, description]) => `<a class="card" href="${docsBase}${path}"><span class="card-icon" aria-hidden="true">§</span><h2>${escapeHtml(title)}</h2><p>${escapeHtml(description)}</p><span>Open Markdown article →</span></a>`).join("");
  }

  function renderStatus() {
    const counts = features.reduce((result, feature) => {
      result.web[feature.web] = (result.web[feature.web] || 0) + 1;
      result.desktop[feature.desktop] = (result.desktop[feature.desktop] || 0) + 1;
      return result;
    }, { web: {}, desktop: {} });
    const implemented = counts.web.implemented || 0;
    $("#feature-count").textContent = String(features.length);
    $("#implemented-count").textContent = String(implemented);
    const cards = [
      ["Web implementation", `${implemented} implemented`, "Implemented means a working local behavior exists in this site."],
      ["Desktop implementation", `${counts.desktop.implemented || 0} implemented`, "No desktop behavior is upgraded without built-artifact evidence."],
      ["Explicit exclusions", `${counts.web.excluded || 0} excluded`, "Only the file converter and local Ollama manager are excluded by current scope."],
      ["Installer", "Unavailable", "No verified release manifest or immutable installer URL is present."],
      ["Network", "None required", "Site preferences, filters, palette, and inventory run locally."],
      ["Status Hub", "Unavailable", "This lane could not publish to the shared authenticated status surface."]
    ];
    $("#status-grid").innerHTML = cards.map(([title, value, detail]) => `<article class="card"><h2>${escapeHtml(title)}</h2><strong>${escapeHtml(value)}</strong><p>${escapeHtml(detail)}</p></article>`).join("");
    const commit = typeof buildMetadata.commit === "string" && /^[0-9a-f]{40}$/.test(buildMetadata.commit) ? buildMetadata.commit : null;
    const generatedAt = typeof buildMetadata.generatedAt === "string" && !Number.isNaN(Date.parse(buildMetadata.generatedAt)) ? buildMetadata.generatedAt : null;
    $("#status-build-evidence").textContent = commit && generatedAt
      ? `Generated from commit ${commit.slice(0, 12)} at ${new Date(generatedAt).toLocaleString()}. Values are derived from the checked-in feature inventory.`
      : "Build commit and generation time are unavailable in this static source preview. Values are derived from the checked-in feature inventory.";
  }

  function filterSettings() {
    const query = $("#settings-search").value.trim();
    let shown = 0;
    $$(".setting-card").forEach((card) => {
      const value = `${card.dataset.search} ${card.textContent}`;
      let matches = !query || value.toLocaleLowerCase().includes(query.toLocaleLowerCase());
      if (settingsRegex) matches = settingsRegex.test(value);
      settingsRegex?.lastIndex && (settingsRegex.lastIndex = 0);
      card.hidden = !matches;
      if (matches) shown += 1;
    });
    $("#settings-result-count").textContent = shown === 0 ? "No settings match the current search." : `${shown} setting${shown === 1 ? "" : "s"} shown.`;
  }

  function compileRegex() {
    const pattern = $("#regex-pattern").value;
    if (pattern.length > 256) throw new Error("Pattern is limited to 256 characters.");
    const flags = `${$("#flag-i").checked ? "i" : ""}${$("#flag-m").checked ? "m" : ""}`;
    return new RegExp(pattern, flags);
  }

  function updateRegexFeedback() {
    try {
      const expression = compileRegex();
      const sample = $("#regex-sample").value.slice(0, 4096);
      const matches = [...sample.matchAll(new RegExp(expression.source, expression.flags.includes("g") ? expression.flags : `${expression.flags}g`))].slice(0, 100);
      $("#regex-feedback").textContent = `Valid JavaScript pattern. ${matches.length} sample match${matches.length === 1 ? "" : "es"}.`;
    } catch (error) {
      $("#regex-feedback").textContent = `Invalid pattern: ${error.message}`;
    }
  }

  function renderPalette(query = "") {
    const normalized = query.trim().toLocaleLowerCase();
    const results = paletteCommands.filter((command) => !normalized || `${command.label} ${command.description}`.toLocaleLowerCase().includes(normalized));
    $("#palette-results").innerHTML = results.map((command) => `<button type="button" class="palette-result" data-command="${command.id}" data-type="${command.type}"><span><strong>${escapeHtml(command.label)}</strong><br><small>${escapeHtml(command.description)}</small></span><span aria-hidden="true">→</span></button>`).join("") || "<p>No commands match.</p>";
  }

  function openPalette() {
    renderPalette();
    if (!$("#palette").open) $("#palette").showModal();
    window.setTimeout(() => $("#palette-search").focus(), 0);
  }

  function executeCommand(id, type) {
    $("#palette").close();
    if (type === "page") {
      activatePage(id);
      return;
    }
    activatePage("settings", false);
    const target = document.getElementById(id);
    target?.scrollIntoView({ block: "center", behavior: "smooth" });
    target?.focus();
    target?.closest(".setting-card, .search-builder-wrap")?.classList.add("highlight");
    window.setTimeout(() => target?.closest(".setting-card, .search-builder-wrap")?.classList.remove("highlight"), 1200);
  }

  $$(".tabs [role='tab']").forEach((tab, index, tabs) => {
    tab.tabIndex = tab.getAttribute("aria-selected") === "true" ? 0 : -1;
    tab.addEventListener("click", () => activatePage(tab.dataset.tab));
    tab.addEventListener("keydown", (event) => {
      const delta = event.key === "ArrowDown" ? 1 : event.key === "ArrowUp" ? -1 : 0;
      if (!delta) return;
      event.preventDefault();
      tabs[(index + delta + tabs.length) % tabs.length].focus();
    });
  });
  $$('[data-go]').forEach((button) => button.addEventListener("click", () => activatePage(button.dataset.go)));
  $("#open-nav").addEventListener("click", () => setDrawer(true));
  $("#close-nav").addEventListener("click", () => setDrawer(false, true));
  mobileNavigation.addEventListener?.("change", () => setDrawer(false, false));
  ["feature-search", "surface-filter", "status-filter"].forEach((id) => document.getElementById(id).addEventListener("input", renderFeatureInventory));
  $("#theme-setting").addEventListener("change", (event) => { preferences.theme = event.target.value; applyPreferences(); savePreferences(); });
  $("#language-setting").addEventListener("change", (event) => { preferences.language = event.target.value; applyPreferences(); savePreferences(); });
  $("#en-funny").addEventListener("input", (event) => { preferences.enFunny = Number(event.target.value); applyPreferences(); savePreferences(false); });
  $("#en-funny").addEventListener("change", () => showToast(localized("saved")));
  $("#yue-funny").addEventListener("input", (event) => { preferences.yueFunny = Number(event.target.value); applyPreferences(); savePreferences(false); });
  $("#yue-funny").addEventListener("change", () => showToast(localized("saved")));
  $("#settings-search").addEventListener("input", () => { settingsRegex = null; filterSettings(); });
  $("#regex-toggle").addEventListener("click", () => {
    const builder = $("#regex-builder");
    builder.hidden = !builder.hidden;
    $("#regex-toggle").setAttribute("aria-expanded", String(!builder.hidden));
    if (!builder.hidden) $("#regex-pattern").focus();
  });
  $$("[data-insert]").forEach((button) => button.addEventListener("click", () => {
    const input = $("#regex-pattern");
    const token = button.dataset.insert === "( )" ? "()" : button.dataset.insert;
    input.setRangeText(token, input.selectionStart, input.selectionEnd, "end");
    updateRegexFeedback();
    input.focus();
  }));
  ["regex-pattern", "flag-i", "flag-m", "regex-sample"].forEach((id) => document.getElementById(id).addEventListener("input", updateRegexFeedback));
  $("#apply-regex").addEventListener("click", () => {
    try { settingsRegex = compileRegex(); $("#settings-search").value = $("#regex-pattern").value; filterSettings(); showToast("Regex applied to settings search."); }
    catch (error) { $("#regex-feedback").textContent = `Invalid pattern: ${error.message}`; }
  });
  $("#copy-regex").addEventListener("click", async () => {
    try { await navigator.clipboard.writeText($("#regex-pattern").value); showToast("Regex pattern copied."); }
    catch { showToast("Copy was unavailable. Select the pattern and copy it manually."); }
  });
  $("#vocabulary-upload").addEventListener("change", (event) => {
    event.target.value = "";
    $("#vocabulary-status").textContent = "File not loaded. Validation and replacement are unavailable in this documentation build.";
    showToast("Personal vocabulary processing is not implemented; no file was read or stored.");
  });
  $("#reset-settings").addEventListener("click", () => {
    if (!window.confirm("Reset this site's locally stored theme, language, and funny-level preferences?")) return;
    try {
      localStorage.removeItem(storageKey);
      preferenceStorageAvailable = true;
      setPreferenceStatus("Site preferences were reset to shipped defaults.");
    } catch {
      preferenceStorageAvailable = false;
      setPreferenceStatus("Local preference storage refused the reset. Shipped defaults are active for this page only.");
    }
    preferences = { ...defaultPreferences };
    settingsRegex = null;
    applyPreferences();
    showToast(localized("reset"));
  });
  $("#palette-launch").addEventListener("click", openPalette);
  $("#palette-search").addEventListener("input", (event) => renderPalette(event.target.value));
  $("#palette-results").addEventListener("click", (event) => {
    const button = event.target.closest("[data-command]");
    if (button) executeCommand(button.dataset.command, button.dataset.type);
  });
  document.addEventListener("keydown", (event) => {
    if (event.ctrlKey && event.shiftKey && event.key.toLocaleLowerCase() === "f") { event.preventDefault(); openPalette(); }
    if (event.key === "Escape" && mobileNavigation.matches && $("#rail").classList.contains("open")) { event.preventDefault(); setDrawer(false, true); }
  });

  renderFeatureInventory();
  renderDocs();
  renderStatus();
  applyPreferences();
  setDrawer(false, false);
  updateRegexFeedback();
  activatePage(location.hash.slice(1) || "home", false);
})();

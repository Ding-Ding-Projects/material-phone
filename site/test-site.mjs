import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import test from "node:test";

const siteRoot = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.dirname(siteRoot);
const read = (relative) => readFileSync(path.join(repoRoot, relative), "utf8");
const inventory = JSON.parse(read("site/data/feature-inventory.json"));
const html = read("site/index.html");
const css = read("site/styles.css");
const appSource = read("site/app.ts");

const requiredFeatureIds = [
  "language-modes", "funny-levels", "dialog-emojis", "school-mode", "personal-vocabulary", "narrator",
  "scheduled-settings", "dim-sum-surprise", "nonblocking-notifications", "material-design", "appearance-controls",
  "per-element-appearance", "infinite-color-picker", "app-rename", "app-logo-customization", "tabs", "tab-pinning",
  "tab-groups", "tab-searches", "tab-bulk-close", "regex-builder", "menu-search", "command-palette", "guided-forms",
  "rich-controls", "settings-explanations", "adhd-modes", "super-confirmation", "bulk-actions", "local-history",
  "changelog-viewer", "offline-docs", "external-editor", "exports", "archive-export", "authenticator", "totp-qr",
  "toy-locks", "support-tickets", "unlock-ladder", "forge-publishing", "copy-push", "provider-markup",
  "failure-recovery", "long-operation-progress", "overlay-surfaces", "context-shortcuts", "responsive-sizing",
  "accessibility", "status-hub", "browser-download-dialogs", "automatic-updates", "squirrel-installer",
  "day-teet-hui-boundary", "download-link", "social-preview", "capture-evidence", "design-reference-parity",
  "notifications-bulk", "filters-collapse", "blank-slate-presets", "call-runtime", "universal-file-converter",
  "local-ollama-suite-manager"
];
const allowedStates = new Set(["implemented", "documented", "planned", "excluded"]);

function validateInventory(candidate) {
  assert.equal(candidate.schemaVersion, 1);
  assert.ok(Array.isArray(candidate.features));
  assert.deepEqual(candidate.features.map((feature) => feature.id), requiredFeatureIds, "inventory order and exact boundaries must match the hand-written canonical list");
  const ids = new Set();
  for (const feature of candidate.features) {
    assert.match(feature.id, /^[a-z0-9]+(?:-[a-z0-9]+)*$/);
    assert.ok(!ids.has(feature.id), `duplicate feature id ${feature.id}`);
    ids.add(feature.id);
    assert.ok(feature.name.length > 4, `${feature.id} needs a public name`);
    assert.ok(allowedStates.has(feature.desktop), `${feature.id} has invalid desktop state`);
    assert.ok(allowedStates.has(feature.web), `${feature.id} has invalid web state`);
    assert.ok(feature.evidence.length > 20, `${feature.id} needs specific evidence or next action`);
  }
  assert.deepEqual(candidate.explicitExclusions, ["universal-file-converter", "local-ollama-suite-manager"]);
  const excluded = candidate.features.filter((feature) => feature.desktop === "excluded" || feature.web === "excluded").map((feature) => feature.id);
  assert.deepEqual(excluded, candidate.explicitExclusions);
}

test("feature inventory is exact, explicit, and evidence-labelled", () => validateInventory(inventory));

test("inventory negative regression turns red when one canonical row disappears", () => {
  const broken = structuredClone(inventory);
  broken.features = broken.features.filter((feature) => feature.id !== "command-palette");
  assert.throws(() => validateInventory(broken), /inventory order and exact boundaries/);
  validateInventory(inventory);
});

test("generated browser files are current", () => {
  execFileSync(process.execPath, [path.join(siteRoot, "build-site.mjs")], { cwd: repoRoot, stdio: "pipe" });
  const expectedInventory = `// Generated from data/feature-inventory.json by build-site.mjs. Do not edit directly.\nwindow.MATERIAL_PHONE_FEATURES = ${JSON.stringify(inventory.features, null, 2)};\n`;
  const expectedApp = `// Generated from app.ts by build-site.mjs. Do not edit directly.\n${appSource}`;
  assert.equal(read("site/inventory.js"), expectedInventory);
  assert.equal(read("site/app.js"), expectedApp);
  execFileSync(process.execPath, ["--check", path.join(siteRoot, "app.js")], { cwd: repoRoot, stdio: "pipe" });
});

test("HTML exposes linked vertical tabs and an explicit runtime boundary", () => {
  for (const page of ["home", "features", "docs", "download", "status", "settings"]) {
    assert.match(html, new RegExp(`data-tab="${page}"`));
    assert.match(html, new RegExp(`id="${page}-panel"`));
    assert.match(html, new RegExp(`aria-controls="${page}-panel"`));
  }
  assert.match(html, /role="tablist" aria-orientation="vertical"/);
  assert.match(html, /not the calling runtime and does not place or receive calls/i);
  assert.match(html, /<button class="filled-button" disabled aria-describedby="download-blocker">/);
});

test("settings, regex builder, and command palette have complete structural wiring", () => {
  for (const id of ["theme-setting", "language-setting", "en-funny", "yue-funny", "settings-search", "regex-toggle", "regex-pattern", "regex-sample", "apply-regex", "copy-regex", "vocabulary-upload", "reset-settings", "palette", "palette-search"]) {
    assert.match(html, new RegExp(`id="${id}"`), `missing ${id}`);
  }
  assert.match(appSource, /event\.ctrlKey && event\.shiftKey/);
  assert.match(appSource, /key\.toLocaleLowerCase\(\) === "f"/);
  assert.match(appSource, /Pattern is limited to 256 characters/);
  assert.match(appSource, /slice\(0, 4096\)/);
  assert.match(appSource, /slice\(0, 100\)/);
  assert.match(appSource, /event\.target\.value = ""/);
  assert.match(appSource, /no file was read or stored/i);
  assert.match(appSource, /preferences\.enFunny - 1/);
  assert.match(appSource, /preferences\.yueFunny - 1/);
});

test("site is responsive, focus-visible, reduced-motion aware, and internally scrollable", () => {
  assert.match(css, /:focus-visible/);
  assert.match(css, /@media \(prefers-reduced-motion: reduce\)/);
  assert.match(css, /@media \(max-width: 900px\)/);
  assert.match(css, /@media \(max-width: 600px\)/);
  assert.match(css, /\.table-wrap \{ overflow:auto/);
  assert.match(css, /min-height: 44px/);
  assert.match(html, /class="skip-link" href="#main"/);
  assert.match(html, /aria-live="polite"/);
});

test("site assets are local and analytics-free", () => {
  const assetAttributes = [...html.matchAll(/(?:src|href)="([^"]+)"/g)].map((match) => match[1]);
  const networkAssets = assetAttributes.filter((value) => /^(?:https?:)?\/\//i.test(value));
  assert.deepEqual(networkAssets, []);
  assert.doesNotMatch(html, /analytics|telemetry|tracker|googletagmanager|fonts\.googleapis/i);
  assert.doesNotMatch(appSource, /\bfetch\s*\(|XMLHttpRequest|WebSocket|sendBeacon/);
});

test("categorized feature articles have required sections and valid suggested links", () => {
  const articles = [
    "docs/site/architecture.md", "docs/site/navigation.md", "docs/site/settings.md", "docs/site/regex-builder.md",
    "docs/features/inventory.md", "docs/delivery/status-downloads.md", "docs/quality/accessibility.md",
    "docs/quality/privacy-security.md", "docs/project/provenance.md"
  ];
  for (const article of articles) {
    const body = read(article);
    for (const heading of ["Behavior", "Configuration", "Failure modes", "Security", "Verification", "Suggested articles"]) {
      assert.match(body, new RegExp(`^## ${heading}`, "m"), `${article} missing ${heading}`);
    }
    for (const match of body.matchAll(/\[[^\]]+\]\(([^)]+\.md)\)/g)) {
      const destination = path.resolve(path.dirname(path.join(repoRoot, article)), match[1]);
      assert.ok(existsSync(destination), `${article} has missing link ${match[1]}`);
    }
  }
});

test("public changed prose contains no private vocabulary", () => {
  const publicFiles = [
    "README.md", "ROADMAP.md", "HANDOFF.md", "AGENTS.md", "UPSTREAM.md", "CHANGELOG.md", "CONTRIBUTING.md", "SECURITY.md", "CODE_OF_CONDUCT.md",
    "site/index.html", "site/styles.css", "site/app.ts", "site/build-site.mjs", "site/data/feature-inventory.json",
    ...[
      "docs/README.md", "docs/site/README.md", "docs/site/architecture.md", "docs/site/navigation.md", "docs/site/settings.md", "docs/site/regex-builder.md",
      "docs/features/README.md", "docs/features/inventory.md", "docs/delivery/README.md", "docs/delivery/status-downloads.md",
      "docs/quality/README.md", "docs/quality/accessibility.md", "docs/quality/privacy-security.md", "docs/project/README.md", "docs/project/provenance.md"
    ]
  ];
  const privateTerms = [
    "Gerk Tong Hui", "Day Teet Hui", "GitHui", "Fay Gay", "Mat Day", "Cup Chun", "Lap Sap Tong", "Chong Leung",
    "Chicken ai", "Herng Ha Yern Geen", "Lang gui", "HuiShot", "poke guy", "See Fut", "huipoint", "Taylor Swift",
    "Hong Kong Dim Sum", "Hong Kong Dim Sum", "I am dewing hui", "dew qure lo mo", "@uh"
  ];
  const combined = publicFiles.map((file) => `${file}\n${read(file)}`).join("\n");
  for (const term of privateTerms) assert.ok(!combined.toLocaleLowerCase().includes(term.toLocaleLowerCase()), `private term leaked: ${term}`);
});

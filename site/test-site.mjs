import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, existsSync, mkdtempSync, rmSync } from "node:fs";
import { fileURLToPath } from "node:url";
import os from "node:os";
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
  "landing-documentation-boundary", "download-link", "social-preview", "capture-evidence", "design-reference-parity",
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
  assert.deepEqual(candidate.features.filter((feature) => feature.web === "implemented").map((feature) => feature.id), ["landing-documentation-boundary"]);
  assert.equal(candidate.features.find((feature) => feature.id === "status-hub").web, "planned");
}

function validateAccessibleShell(candidateHtml) {
  assert.match(candidateHtml, /id="open-nav"[^>]+aria-controls="rail"[^>]+aria-expanded="false"/);
  assert.match(candidateHtml, /id="rail"[^>]+aria-hidden="false"/);
  for (const page of ["home", "features", "docs", "download", "status", "settings"]) {
    assert.match(candidateHtml, new RegExp(`id="${page}-tab"[^>]+aria-controls="${page}-panel"`));
    assert.match(candidateHtml, new RegExp(`id="${page}-panel"[^>]+aria-labelledby="${page}-tab"`));
  }
  assert.doesNotMatch(candidateHtml, /role="listbox"|role="option"/);
}

test("feature inventory is exact, explicit, and evidence-labelled", () => validateInventory(inventory));

test("inventory negative regression turns red when one canonical row disappears", () => {
  const broken = structuredClone(inventory);
  broken.features = broken.features.filter((feature) => feature.id !== "command-palette");
  assert.throws(() => validateInventory(broken), /inventory order and exact boundaries/);
  validateInventory(inventory);
});

test("generated browser files are current before the generator writes", () => {
  const before = [read("site/inventory.js"), read("site/app.js"), read("site/metadata.js")];
  execFileSync(process.execPath, [path.join(siteRoot, "build-site.mjs"), "--check"], { cwd: repoRoot, stdio: "pipe" });
  assert.deepEqual([read("site/inventory.js"), read("site/app.js"), read("site/metadata.js")], before, "freshness check must not rewrite tracked output");
  execFileSync(process.execPath, ["--check", path.join(siteRoot, "app.js")], { cwd: repoRoot, stdio: "pipe" });
});

test("stale tracked output turns red before restoration", () => {
  const target = path.join(siteRoot, "app.js");
  const original = readFileSync(target, "utf8");
  try {
    writeFileSync(target, `${original}\n// deliberate stale-output probe\n`, "utf8");
    assert.throws(
      () => execFileSync(process.execPath, [path.join(siteRoot, "build-site.mjs"), "--check"], { cwd: repoRoot, stdio: "pipe" }),
      /Generated site output is stale/
    );
  } finally {
    writeFileSync(target, original, "utf8");
  }
  execFileSync(process.execPath, [path.join(siteRoot, "build-site.mjs"), "--check"], { cwd: repoRoot, stdio: "pipe" });
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

test("accessible shell negative proof turns red when drawer control wiring disappears", () => {
  validateAccessibleShell(html);
  const broken = html.replace(' aria-controls="rail"', "");
  assert.throws(() => validateAccessibleShell(broken), /aria-controls/);
  validateAccessibleShell(html);
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
  assert.match(appSource, /allowedThemes\.has/);
  assert.match(appSource, /allowedLanguages\.has/);
  assert.match(appSource, /Local preference storage refused the update/);
  assert.match(appSource, /settings-result-count/);
  assert.doesNotMatch(appSource, /document\.lastModified/);
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
  for (const file of ["site/index.html", "site/styles.css", "site/app.ts", "site/inventory.js", "site/metadata.js"]) {
    const body = read(file);
    assert.doesNotMatch(body, /(?:src|href|url)\s*(?:=|\()\s*["']?(?:https?:)?\/\//i, `${file} contains a network asset reference`);
  }
});
test("Pages workflow uses reviewed immutable action pins", () => {
  const workflow = read(".github/workflows/pages.yml");
  const pins = [
    ["actions/checkout", "11d5960a326750d5838078e36cf38b85af677262", "v4"],
    ["actions/configure-pages", "983d7736d9b0ae728b81ab479565c72886d7745b", "v5"],
    ["actions/upload-pages-artifact", "7b1f4a764d45c48632c6b24a0339c27f5614fb0b", "v4"],
    ["actions/deploy-pages", "d6db90164ac5ed86f2b6aed7e0febac5b3c0c03e", "v4"]
  ];
  for (const [action, sha, tag] of pins) assert.match(workflow, new RegExp(`uses: ${action}@${sha} # ${tag}`));
  assert.doesNotMatch(workflow, /uses:\s+actions\/[^@\s]+@v\d+/);
});

test("staged Pages artifact contains the website and resolvable documentation", () => {
  const artifact = mkdtempSync(path.join(os.tmpdir(), "material-phone-pages-"));
  const env = { ...process.env, SITE_COMMIT: "0123456789abcdef0123456789abcdef01234567", SITE_BUILD_TIME: "2026-08-22T12:00:00Z", SITE_DOCS_BASE: "docs/" };
  try {
    execFileSync(process.execPath, [path.join(siteRoot, "build-site.mjs")], { cwd: repoRoot, env, stdio: "pipe" });
    execFileSync(process.execPath, [path.join(siteRoot, "stage-pages.mjs"), artifact], { cwd: repoRoot, stdio: "pipe" });
    execFileSync(process.execPath, [path.join(siteRoot, "check-pages-artifact.mjs"), artifact], { cwd: repoRoot, stdio: "pipe" });
  } finally {
    execFileSync(process.execPath, [path.join(siteRoot, "build-site.mjs")], { cwd: repoRoot, stdio: "pipe" });
    rmSync(artifact, { recursive: true, force: true });
  }
  execFileSync(process.execPath, [path.join(siteRoot, "build-site.mjs"), "--check"], { cwd: repoRoot, stdio: "pipe" });
});

test("deployed metadata identifies the canonical documentation URL", () => {
  assert.match(html, /property="og:url" content="https:\/\/ding-ding-projects\.github\.io\/material-phone\/"/);
  assert.match(html, /name="twitter:card" content="summary_large_image"/);
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

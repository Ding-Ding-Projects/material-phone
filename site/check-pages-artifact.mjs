import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";

const requestedTarget = process.argv[2] || "";
const target = path.resolve(requestedTarget);
if (!requestedTarget || !path.isAbsolute(requestedTarget) || !/^material-phone-pages(?:-|$)/.test(path.basename(target))) {
  throw new Error("Provide the absolute task-scoped material-phone-pages artifact path.");
}

const required = [
  "index.html", "styles.css", "inventory.js", "metadata.js", "app.js", "docs/README.md",
  "docs/site/architecture.md", "docs/site/navigation.md", "docs/site/settings.md", "docs/site/regex-builder.md",
  "docs/features/inventory.md", "docs/delivery/status-downloads.md", "docs/quality/accessibility.md",
  "docs/quality/privacy-security.md", "docs/project/provenance.md"
];
for (const relative of required) assert.ok(existsSync(path.join(target, relative)), `Pages artifact is missing ${relative}`);

const html = readFileSync(path.join(target, "index.html"), "utf8");
for (const reference of ["styles.css", "inventory.js", "metadata.js", "app.js"]) {
  assert.match(html, new RegExp(`(?:href|src)="${reference}"`), `index.html does not reference ${reference}`);
}
const metadata = readFileSync(path.join(target, "metadata.js"), "utf8");
assert.match(metadata, /"docsBase": "docs\/"/, "Published metadata must resolve documentation from the artifact root.");

const app = readFileSync(path.join(target, "app.js"), "utf8");
for (const match of app.matchAll(/\["[^"]+", "([^"]+\.md)",/g)) {
  assert.ok(existsSync(path.join(target, "docs", match[1])), `Documentation card target is missing: ${match[1]}`);
}
console.log(`Pages artifact contract passed with ${required.length} required files.`);

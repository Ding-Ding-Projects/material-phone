import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const siteRoot = dirname(fileURLToPath(import.meta.url));
const inventory = JSON.parse(readFileSync(join(siteRoot, "data", "feature-inventory.json"), "utf8"));
const appSource = readFileSync(join(siteRoot, "app.ts"), "utf8");

const inventoryOutput = `// Generated from data/feature-inventory.json by build-site.mjs. Do not edit directly.\nwindow.MATERIAL_PHONE_FEATURES = ${JSON.stringify(inventory.features, null, 2)};\n`;
const appOutput = `// Generated from app.ts by build-site.mjs. Do not edit directly.\n${appSource}`;

writeFileSync(join(siteRoot, "inventory.js"), inventoryOutput, "utf8");
writeFileSync(join(siteRoot, "app.js"), appOutput, "utf8");

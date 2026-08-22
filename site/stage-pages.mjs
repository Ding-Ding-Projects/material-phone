import { cp, mkdir, rm } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const siteRoot = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.dirname(siteRoot);
const requestedTarget = process.argv[2] || "";
const target = path.resolve(requestedTarget);
const targetName = path.basename(target);
if (!requestedTarget || !path.isAbsolute(requestedTarget) || target === repoRoot || target === siteRoot || !/^material-phone-pages(?:-|$)/.test(targetName)) {
  throw new Error("Provide an absolute, task-scoped material-phone-pages artifact directory outside the repository site source.");
}

await rm(target, { recursive: true, force: true });
await mkdir(target, { recursive: true });
for (const file of ["index.html", "styles.css", "inventory.js", "metadata.js", "app.js"]) {
  await cp(path.join(siteRoot, file), path.join(target, file));
}
await cp(path.join(repoRoot, "docs"), path.join(target, "docs"), { recursive: true });
console.log(`Staged Pages artifact at ${target}.`);

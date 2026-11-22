// Lists every t("...") key in the app that has no French translation in lib/i18n/fr.ts.
// Usage: node scripts/check-i18n.mjs        (exit code 1 if anything is missing)
//        node scripts/check-i18n.mjs --all  (print every key found)
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const ROOTS = ["app", "components", "lib"];
const FR_FILE = join("lib", "i18n", "fr.ts");
const files = [];
const walk = (dir) => {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p);
    else if (/\.(tsx?|mjs)$/.test(name) && p !== FR_FILE) files.push(p);
  }
};
ROOTS.forEach(walk);

const unescape = (s) => s.replace(/\\(["'])/g, "$1");

// Keys stored in constants first, then passed through t() at render time.
const INDIRECT = [/label:\s*"([^"]+)"/g, /hint:\s*"([^"]+)"/g, /blurb:\s*"([^"]+)"/g, /name:\s*"([^"]+)"/g];
const INDIRECT_FILES = /menu-options\.ts$|layout\.tsx$|signup/;
const CONST_MAPS = /(STATUS_TEXT|STATUS_LABEL|ROLE_LABEL|VEHICLE_TEXT)[^=]*=\s*\{([\s\S]*?)\};/g;

const keys = new Map();
const add = (k, f) => {
  if (!keys.has(k)) keys.set(k, f);
};

for (const f of files) {
  const src = readFileSync(f, "utf8");
  // t("literal") / t('literal') / getT()("literal")
  for (const m of src.matchAll(/(?:\bt|getT\(\))\(\s*(["'])((?:\\.|(?!\1).)*?)\1/g)) add(unescape(m[2]), f);
  // t(cond ? "a" : "b")
  for (const m of src.matchAll(/\bt\(\s*[^()?]+\?\s*"([^"]+)"\s*:\s*"([^"]+)"/g)) {
    add(m[1], f);
    add(m[2], f);
  }
  if (INDIRECT_FILES.test(f)) for (const re of INDIRECT) for (const m of src.matchAll(re)) add(m[1], f);
  for (const m of src.matchAll(CONST_MAPS)) for (const v of m[2].matchAll(/:\s*"([^"]+)"/g)) add(v[1], f);
}
// ImageUploader builds `Add ${label}` / `Change ${label}` from these labels.
for (const label of ["photo", "logo", "cover photo"]) {
  add(`Add ${label}`, "components/ImageUploader.tsx");
  add(`Change ${label}`, "components/ImageUploader.tsx");
}

const frSrc = readFileSync(FR_FILE, "utf8");
// Keys may be quoted ("Sign in": …) or bare identifiers (Total: …).
const frKeys = new Set(
  [...frSrc.matchAll(/^\s*(?:(["'])((?:\\.|(?!\1).)*?)\1|([A-Za-z_$][\w$]*))\s*:/gm)].map((m) =>
    m[3] ?? unescape(m[2])
  )
);

if (process.argv.includes("--all")) {
  for (const k of [...keys.keys()].sort()) console.log(k);
  process.exit(0);
}
const missing = [...keys].filter(([k]) => !frKeys.has(k));
if (missing.length) {
  console.log(`${missing.length} key(s) missing a French translation:`);
  for (const [k, f] of missing) console.log(`  ${JSON.stringify(k)}   (${f})`);
  process.exit(1);
}
console.log(`All ${keys.size} keys have a French translation.`);

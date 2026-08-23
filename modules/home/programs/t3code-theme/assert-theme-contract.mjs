// Fails the build when t3code moves the localStorage theme contract. The boot
// script writes a shape and key names nothing else in the build references, so a
// rename upstream would otherwise leave a green build and an unthemed app.
import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { runInNewContext } from "node:vm";

const [clientDir, contractPath] = process.argv.slice(2);
const contract = JSON.parse(readFileSync(contractPath, "utf8"));

function fail(message) {
  console.error(`t3code theme contract: ${message}`);
  process.exit(1);
}

const indexHtml = readFileSync(path.join(clientDir, "index.html"), "utf8");
const assetDir = path.join(clientDir, "assets");
const bundles = readdirSync(assetDir)
  .filter((name) => /^index-.*\.js$/.test(name))
  .map((name) => readFileSync(path.join(assetDir, name), "utf8"));
if (bundles.length === 0) fail(`no client bundle under ${assetDir}`);
const source = [indexHtml, ...bundles].join("\n");

const missingKeys = contract.storageKeys.filter((key) => !source.includes(key));
if (missingKeys.length > 0) {
  fail(
    "these localStorage keys are gone, so the theme would install into " +
      `nothing: ${missingKeys.join(", ")}`,
  );
}

// The minifier collapses THEME_COLOR_ROLES into a dot-joined literal.
const roleMatches = [
  ...source.matchAll(/`(canvas\.chrome\.[A-Za-z.]+)`\.split/g),
];
if (roleMatches.length !== 1) {
  fail(
    "could not read THEME_COLOR_ROLES out of the client bundle; the role " +
      "check in assert-theme-contract.mjs needs updating for this release",
  );
}
const upstreamRoles = new Set(roleMatches[0][1].split("."));
const ourRoles = new Set(Object.keys(contract.theme.colors));
const added = [...upstreamRoles].filter((role) => !ourRoles.has(role));
const dropped = [...ourRoles].filter((role) => !upstreamRoles.has(role));
if (added.length > 0 || dropped.length > 0) {
  const problems = [];
  if (added.length > 0)
    problems.push(`t3code added roles: ${added.join(", ")}`);
  if (dropped.length > 0) {
    problems.push(`t3code dropped roles: ${dropped.join(", ")}`);
  }
  fail(`${problems.join("; ")} — update programs.t3code.theme.colors`);
}

// Validate the stored shape with t3code's own guard rather than a copy of it,
// so a rename like label -> name cannot pass unnoticed.
const bootScript = indexHtml.split("<script>")[1]?.split("</script>")[0] ?? "";
const start = bootScript.indexOf("const RESERVED_THEME_IDS");
const end = bootScript.indexOf("const findCustomTheme");
if (start === -1 || end <= start) {
  fail(
    "could not extract isStoredCustomTheme from index.html; the shape check " +
      "in assert-theme-contract.mjs needs updating for this release",
  );
}
const context = { theme: contract.theme, accepted: undefined };
runInNewContext(
  `${bootScript.slice(start, end)}\naccepted = isStoredCustomTheme(theme);`,
  context,
);
if (context.accepted !== true) {
  fail(
    "t3code's own isStoredCustomTheme rejects the generated theme, so the " +
      "stored theme shape moved",
  );
}

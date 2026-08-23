// Exercises the generated boot script against a localStorage stub.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";

const [scriptPath, expectedId] = process.argv.slice(2);
const source = readFileSync(scriptPath, "utf8");

function makeStore(initial = {}) {
  const data = new Map(Object.entries(initial));
  return {
    data,
    getItem: (key) => (data.has(key) ? data.get(key) : null),
    setItem: (key, value) => data.set(key, String(value)),
    removeItem: (key) => data.delete(key),
  };
}

let errors = [];
function run(store) {
  runInNewContext(source, {
    window: { localStorage: store },
    console: { error: (...args) => errors.push(args) },
  });
  return store;
}

const THEMES = "t3code:themes:v1";
const SELECTED = "t3code:theme";
const APPEARANCE = "t3code:theme-appearance-mode";
const FOLLOW_SYSTEM = "t3code:theme-follow-system";
const HALVES = "t3code:theme-halves:v1";
const REVISION = "t3code:managed-theme-revision";

// Installs the theme and selects it on a first run.
{
  const store = run(makeStore());
  assert.deepEqual(errors, []);
  const library = JSON.parse(store.getItem(THEMES));
  assert.equal(library.length, 1);
  assert.equal(library[0].id, expectedId);
  assert.ok(library[0].label.length > 0);
  assert.match(library[0].colors.canvas, /^#[0-9a-f]{6}$/);
  assert.equal(store.getItem(SELECTED), expectedId);
  assert.equal(store.getItem(APPEARANCE), library[0].appearance);
  assert.equal(store.getItem(FOLLOW_SYSTEM), "false");
  assert.ok(store.getItem(REVISION).length > 0);
}

// Clears a stored light/dark mix, which would otherwise outrank the selection.
{
  const store = run(
    makeStore({ [HALVES]: '{"light":"ocean","dark":"ember"}' }),
  );
  assert.equal(store.getItem(HALVES), null);
}

// Keeps other installed themes and replaces only its own entry.
{
  const store = run(
    makeStore({
      [THEMES]: JSON.stringify([
        {
          id: "mine",
          label: "Mine",
          appearance: "dark",
          colors: { canvas: "#000000" },
        },
        {
          id: expectedId,
          label: "Stale",
          appearance: "light",
          colors: { canvas: "#ffffff" },
        },
      ]),
    }),
  );
  const library = JSON.parse(store.getItem(THEMES));
  assert.deepEqual(
    library.map((theme) => theme.id),
    ["mine", expectedId],
  );
  assert.notEqual(library[1].label, "Stale");
}

// Leaves a theme chosen in the UI alone while the palette is unchanged.
{
  const store = run(makeStore());
  store.setItem(SELECTED, "ocean");
  run(store);
  assert.equal(store.getItem(SELECTED), "ocean");
  assert.equal(JSON.parse(store.getItem(THEMES))[0].id, expectedId);
}

// Re-selects once the palette moves.
{
  const store = run(makeStore());
  store.setItem(SELECTED, "ocean");
  store.setItem(REVISION, "stale-revision");
  run(store);
  assert.equal(store.getItem(SELECTED), expectedId);
}

// Reports an unreadable library instead of dropping the theme.
{
  errors = [];
  const store = run(makeStore({ [THEMES]: "{not json" }));
  assert.equal(JSON.parse(store.getItem(THEMES))[0].id, expectedId);
  assert.equal(errors.length, 1);
}

// Reports a rejecting localStorage rather than throwing into page load.
{
  errors = [];
  const store = makeStore();
  store.setItem = () => {
    throw new Error("QuotaExceededError");
  };
  run(store);
  assert.equal(errors.length, 1);
}

console.log("boot-script-test: all assertions passed");

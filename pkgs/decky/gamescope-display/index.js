// No bundler: @decky/rollup only externalises @decky/ui to DFL, react to
// SP_REACT and @decky/api to the loader's init hook, so for a plugin this small
// the bundle's output is its input. Plain ES2020 — nothing here is transpiled.
const {
  definePlugin,
  PanelSection,
  PanelSectionRow,
  DropdownItem,
  ButtonItem,
  ToggleField,
  ConfirmModal,
  showModal,
  Field,
  Spinner,
  staticClasses,
} = DFL;

const { createElement: h, useState, useEffect, useCallback } = SP_REACT;

const manifest = { name: "Display Settings" };
const API_VERSION = 2;

const internalAPIConnection =
  window.__DECKY_SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED_deckyLoaderAPIInit;
if (!internalAPIConnection) {
  throw new Error("[display-settings]: loader API was not initialized.");
}
const api = internalAPIConnection.connect(API_VERSION, manifest.name);
const call = api.call;

// Empty means "let the screen decide", which is also what the backend stores.
const AUTO = "";

const screenName = (d) =>
  !d
    ? "Automatic"
    : d.internal
      ? "Built-in screen"
      : `External display (${d.name})`;

const resLabel = (res) => res.replace("x", " × ");

const row = (key, child) => h(PanelSectionRow, { key }, child);

// On Automatic every rate the screen offers is reachable, since gamescope
// matches refresh independently of size.
const ratesFor = (refresh, res) =>
  res === AUTO
    ? [...new Set(Object.values(refresh).flat())].sort((a, b) => b - a)
    : (refresh[res] ?? []);

// "WxH@Hz" with either half optional, so "@240" is any size at 240Hz. The @
// test matches the resolver, which ignores a spec without one.
const parseMode = (spec) => {
  const [res, hz] = spec?.includes("@") ? spec.split("@") : [];
  return { res: res || AUTO, hz: Number(hz) || 0 };
};

const formatFlags = (vrr, hdr) =>
  [vrr && "vrr", hdr && "hdr"].filter(Boolean).join(",");

const formatMode = (res, hz) => (!res && !hz ? "" : `${res}@${hz || ""}`);

const modeSummary = (spec) => {
  const { res, hz } = parseMode(spec);
  const parts = [];
  if (res) parts.push(resLabel(res));
  if (hz) parts.push(`${hz} Hz`);
  return parts.join(" at ") || "automatic resolution";
};

function Panel() {
  const [displays, setDisplays] = useState([]);
  const [preferred, setPreferred] = useState("");
  const [selected, setSelected] = useState("");

  const [resolutions, setResolutions] = useState([]);
  const [refresh, setRefresh] = useState({});
  const [storedMode, setStoredMode] = useState("");
  const [selRes, setSelRes] = useState(AUTO);
  const [selHz, setSelHz] = useState(0);
  const [caps, setCaps] = useState({});
  const [storedFlags, setStoredFlags] = useState("");
  const [selVrr, setSelVrr] = useState(false);
  const [selHdr, setSelHdr] = useState(false);

  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  // Reset leaves the pick unchanged, so the modes effect would not re-run and
  // would keep showing the mode that was just deleted.
  const [reloads, setReloads] = useState(0);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await call("load_displays");
      if (!res.ok) throw new Error(res.error);

      setDisplays(res.displays);
      setPreferred(res.preferred);
      // Start on whatever is stored, so nothing counts as changed until you
      // change it. A pick naming an unplugged screen falls back to Automatic.
      const known = res.displays.some((d) => d.name === res.preferred);
      setSelected(known ? res.preferred : AUTO);
      setReloads((n) => n + 1);
      setError(null);
    } catch (err) {
      setError(String(err?.message ?? err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  // Modes belong to one screen, so they reload whenever the pick changes.
  useEffect(() => {
    if (!selected) return undefined;
    let stale = false;
    (async () => {
      try {
        const m = await call("load_modes", selected);
        if (stale) return;
        if (!m.ok) throw new Error(m.error);

        setResolutions(m.resolutions);
        setRefresh(m.refresh);
        setStoredMode(m.mode);
        setCaps({ vrr: m.canVrr, hdr: m.canHdr });

        // A flag stored against a screen that cannot do it reads as off, so
        // moving a pick between monitors never claims a missing capability.
        const on = (f, able) => able && m.flags.includes(f);
        setSelVrr(on("vrr", m.canVrr));
        setSelHdr(on("hdr", m.canHdr));
        setStoredFlags(formatFlags(on("vrr", m.canVrr), on("hdr", m.canHdr)));

        // Drop a stored half the screen no longer offers, or a dropdown would
        // sit on a value absent from its own option list.
        const { res, hz } = parseMode(m.mode);
        setSelRes(m.resolutions.includes(res) ? res : AUTO);
        setSelHz(ratesFor(m.refresh, AUTO).includes(hz) ? hz : 0);
      } catch (err) {
        if (!stale) setError(String(err?.message ?? err));
      }
    })();
    return () => {
      stale = true;
    };
  }, [selected, reloads]);

  const apply = useCallback(
    async (action) => {
      setBusy(true);
      try {
        const res = await action();
        if (!res.ok) throw new Error(res.error);
        setError(null);
        // Only lands when the restart was declined; otherwise the session is
        // already going down.
        await load();
      } catch (err) {
        setError(String(err?.message ?? err));
      } finally {
        setBusy(false);
      }
    },
    [load],
  );

  const confirm = useCallback(
    (title, description, action) =>
      showModal(
        h(ConfirmModal, {
          strTitle: title,
          strDescription: description,
          strOKButtonText: "Restart now",
          onOK: () => apply(action),
        }),
      ),
    [apply],
  );

  if (loading) {
    return h(PanelSection, null, h(PanelSectionRow, null, h(Spinner, null)));
  }

  const rows = [];

  if (error) {
    rows.push(
      row(
        "error",
        h(
          Field,
          { label: "That didn't work", bottomSeparator: "standard" },
          error,
        ),
      ),
    );
  }

  if (displays.length === 0) {
    rows.push(row("empty", h(Field, { label: "No displays detected" })));
    return h(PanelSection, { title: "Display" }, rows);
  }

  const rates = ratesFor(refresh, selRes);
  const pendingMode = formatMode(selRes, selHz);
  const pendingFlags = formatFlags(selVrr, selHdr);
  const changed =
    selected !== preferred ||
    pendingMode !== storedMode ||
    pendingFlags !== storedFlags;

  rows.push(
    row(
      "current",
      h(
        Field,
        { label: "Now playing on", focusable: true },
        preferred
          ? `${screenName(displays.find((d) => d.name === preferred))}, ${modeSummary(storedMode)}`
          : "Whichever screen Gaming Mode picks",
      ),
    ),
  );

  rows.push(
    row(
      "screen",
      h(DropdownItem, {
        label: "Screen",
        menuLabel: "Play on which screen?",
        rgOptions: [
          { data: AUTO, label: "Automatic" },
          ...displays.map((d) => ({ data: d.name, label: screenName(d) })),
        ],
        selectedOption: selected,
        onChange: (opt) => setSelected(opt.data),
      }),
    ),
  );

  // Size and rate belong to a specific screen, so they only make sense once one
  // is picked.
  if (selected) {
    rows.push(
      row(
        "resolution",
        h(DropdownItem, {
          label: "Resolution",
          menuLabel: "Resolution",
          description:
            selRes === AUTO
              ? "Automatic uses the screen's own preferred size."
              : undefined,
          rgOptions: [
            { data: AUTO, label: "Automatic" },
            ...resolutions.map((r) => ({ data: r, label: resLabel(r) })),
          ],
          selectedOption: selRes,
          onChange: (opt) => {
            setSelRes(opt.data);
            // Keep the chosen rate where the new size still offers it.
            setSelHz(ratesFor(refresh, opt.data).includes(selHz) ? selHz : 0);
          },
        }),
      ),
    );

    if (caps.vrr) {
      rows.push(
        row(
          "vrr",
          h(ToggleField, {
            label: "Variable refresh rate",
            description:
              "Matches the screen to the game's frame rate to cut tearing.",
            checked: selVrr,
            onChange: setSelVrr,
          }),
        ),
      );
    }

    if (caps.hdr) {
      rows.push(
        row(
          "hdr",
          h(ToggleField, {
            label: "HDR",
            description:
              "10-bit output for games that support it; others are tone mapped.",
            checked: selHdr,
            onChange: setSelHdr,
          }),
        ),
      );
    }

    if (rates.length > 0) {
      rows.push(
        row(
          "refresh",
          h(DropdownItem, {
            label: "Refresh rate",
            menuLabel: "Refresh rate",
            rgOptions: [
              { data: 0, label: "Automatic" },
              ...rates.map((hz) => ({ data: hz, label: `${hz} Hz` })),
            ],
            selectedOption: selHz,
            onChange: (opt) => setSelHz(opt.data),
          }),
        ),
      );
    }
  }

  rows.push(
    row(
      "apply",
      h(
        ButtonItem,
        {
          layout: "below",
          disabled: busy || !changed,
          onClick: () =>
            confirm(
              "Restart Gaming Mode?",
              "Steam has to restart to change the display. Quit any running game first — unsaved progress will be lost.",
              // Automatic is the absence of a pick, which is what clearing is.
              () =>
                selected
                  ? call(
                      "set_display",
                      selected,
                      displays.map((d) => d.name),
                      pendingMode,
                      pendingFlags ? pendingFlags.split(",") : [],
                    )
                  : call("clear_display"),
            ),
        },
        changed ? "Apply" : "No changes to apply",
      ),
    ),
  );

  return h(PanelSection, { title: "Display" }, rows);
}

const Icon = () =>
  h(
    "svg",
    { width: "1em", height: "1em", viewBox: "0 0 24 24", fill: "currentColor" },
    h("path", {
      d: "M3 4h18a1 1 0 0 1 1 1v11a1 1 0 0 1-1 1h-7v2h3v2H7v-2h3v-2H3a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1zm1 2v9h16V6H4z",
    }),
  );

export default definePlugin(() => ({
  title: h("div", { className: staticClasses.Title }, "Display Settings"),
  icon: h(Icon, null),
  // decky renders content as `(visible || alwaysRender) && content`, so without
  // this the panel unmounts whenever it hides — including while a dropdown menu
  // is open — and the pick you just made dies with it.
  alwaysRender: true,
  content: h(Panel, null),
}));

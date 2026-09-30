// Retints every colour an Electron app's stylesheets declare onto a base16 palette: greys by lightness, hues by nearest accent.
(PAL, apply) => {
  const cv = document.createElement("canvas");
  cv.width = cv.height = 1;
  const ctx = cv.getContext("2d", { willReadFrequently: true });
  const parse = (c) => {
    ctx.clearRect(0, 0, 1, 1);
    ctx.fillStyle = "#010203";
    ctx.fillStyle = c;
    if (ctx.fillStyle === "#010203" && !/^#010203$/i.test(c)) return null;
    ctx.fillRect(0, 0, 1, 1);
    const d = ctx.getImageData(0, 0, 1, 1).data;
    return [d[0], d[1], d[2], d[3] / 255];
  };
  const lin = (v) => {
    v /= 255;
    return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
  };
  const oklab = ([r, g, b]) => {
    [r, g, b] = [lin(r), lin(g), lin(b)];
    const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return [
      0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s,
    ];
  };
  const hex = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
  const L = (h) => oklab(hex(h))[0];
  const accents = [
    "base08",
    "base09",
    "base0A",
    "base0B",
    "base0C",
    "base0D",
    "base0E",
  ].map((n) => {
    const [, a, b] = oklab(hex(PAL[n]));
    return [n, Math.atan2(b, a)];
  });
  const lo = L(PAL.base01),
    hi = L(PAL.base05),
    SRC_LO = 0.12,
    SRC_HI = 0.98;
  const withAlpha = (h, a) =>
    a >= 0.999
      ? h
      : h +
        Math.round(a * 255)
          .toString(16)
          .padStart(2, "0");
  const map = (rgba) => {
    const [Lv, a, b] = oklab(rgba),
      C = Math.hypot(a, b);
    if (C < 0.05) {
      const t = Math.min(1, Math.max(0, (Lv - SRC_LO) / (SRC_HI - SRC_LO)));
      const pct = Math.round(t * 100);
      const mixed = `color-mix(in oklab, ${PAL.base05} ${pct}%, ${PAL.base01})`;
      return rgba[3] >= 0.999
        ? mixed
        : `color-mix(in srgb, ${mixed} ${Math.round(rgba[3] * 100)}%, transparent)`;
    }
    const h = Math.atan2(b, a);
    let best = accents[0],
      bd = 9;
    for (const acc of accents) {
      let d = Math.abs(h - acc[1]);
      d = Math.min(d, 2 * Math.PI - d);
      if (d < bd) {
        bd = d;
        best = acc;
      }
    }
    return withAlpha(PAL[best[0]], rgba[3]);
  };
  const lum = (h) => {
    const [r, g, b] = hex(h).map(lin);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  };
  const contrast = (x, y) => {
    const [a, b] = [lum(x), lum(y)].sort((p, q) => q - p);
    return (a + 0.05) / (b + 0.05);
  };
  const onFill = (fill) =>
    contrast(PAL.base00, fill) >= contrast(PAL.base05, fill)
      ? PAL.base00
      : PAL.base05;
  const probe = document.createElement("div");
  probe.hidden = true;
  const fills = new Map();
  // Accent a rule paints solid behind its text, with var()s resolved against the live document.
  const accentFill = (raw) => {
    if (!raw || /gradient|url\(/i.test(raw)) return null;
    if (fills.has(raw)) return fills.get(raw);
    probe.style.backgroundColor = "";
    probe.style.backgroundColor = raw;
    const rgba = parse(getComputedStyle(probe).backgroundColor);
    const m = rgba && rgba[3] >= 0.9 ? map(rgba) : null;
    const hit = m && m.startsWith("#") ? m.slice(0, 7) : null;
    fills.set(raw, hit);
    return hit;
  };
  const PROPS = [
    "color",
    "background-color",
    "background-image",
    "background",
    "border-color",
    "border-top-color",
    "border-right-color",
    "border-bottom-color",
    "border-left-color",
    "outline-color",
    "fill",
    "stroke",
    "caret-color",
    "text-decoration-color",
    "column-rule-color",
  ];
  const cache = new Map();
  const convert = (v) => {
    if (cache.has(v)) return cache.get(v);
    let out = null;
    if (v && /gradient\(/i.test(v) && !/var\(|url\(/i.test(v)) {
      let changed = false;
      out = v.replace(
        /#[0-9a-f]{3,8}\b|(?:rgba?|hsla?|oklab|oklch|lab|lch)\([^()]*\)/gi,
        (m) => {
          const rgba = parse(m);
          if (!rgba) return m;
          changed = true;
          return map(rgba);
        },
      );
      if (!changed) out = null;
    } else if (
      v &&
      !/var\(|url\(|gradient|currentcolor|inherit|initial|unset|transparent|none/i.test(
        v,
      )
    ) {
      const trip = /^\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}$/.test(v);
      const rgba = parse(trip ? `rgb(${v})` : v);
      if (rgba) {
        out = map(rgba);
        if (trip) {
          const p = parse(out);
          out = p ? `${p[0]},${p[1]},${p[2]}` : null;
        }
      }
    }
    cache.set(v, out);
    return out;
  };
  const done = new WeakSet();
  const chunks = [];
  const mirror = (rules, wrap) => {
    for (const r of rules) {
      if (r.conditionText !== undefined && r.cssRules) {
        mirror(
          r.cssRules,
          `@${r.constructor.name === "CSSMediaRule" ? "media" : "supports"} ${r.conditionText}`,
        );
        continue;
      }
      if (r.cssRules && !r.style) {
        mirror(r.cssRules, wrap);
        continue;
      }
      if (!r.style || !r.selectorText) continue;
      const decls = [];
      for (let i = 0; i < r.style.length; i++) {
        const p = r.style[i];
        if (!p.startsWith("--") && !PROPS.includes(p)) continue;
        const raw = r.style.getPropertyValue(p).trim();
        if (!raw) continue;
        // Everything is re-declared !important so the copies keep the originals' specificity order.
        const out =
          convert(raw) ??
          (!p.startsWith("--") || /var\(/.test(raw) ? raw : null);
        if (out) decls.push(`${p}: ${out} !important;`);
      }
      const fill = accentFill(
        (
          r.style.getPropertyValue("background-color") ||
          r.style.getPropertyValue("background")
        ).trim(),
      );
      const fg = r.style.getPropertyValue("color").trim();
      const hidden = fg && !/var\(/.test(fg) && (parse(fg)?.[3] ?? 1) < 0.5;
      if (fill && !hidden) {
        const i = decls.findIndex((d) => d.startsWith("color:"));
        if (i >= 0) decls.splice(i, 1);
        decls.push(`color: ${onFill(fill)} !important;`);
      }
      if (!decls.length) continue;
      const rule = `${r.selectorText} { ${decls.join(" ")} }`;
      chunks.push(wrap ? `${wrap} { ${rule} }` : rule);
    }
  };
  const scan = () => {
    let added = false;
    for (const s of document.styleSheets) {
      if (done.has(s) || s.ownerNode?.id === "nix-recolor") continue;
      let rules;
      try {
        rules = s.cssRules;
      } catch {
        continue;
      }
      done.add(s);
      mirror(rules, null);
      added = true;
    }
    if (added) apply(chunks.join("\n"));
  };
  const start = () => {
    document.body.append(probe);
    scan();
    const later = () => {
      clearTimeout(start.t);
      start.t = setTimeout(scan, 300);
    };
    new MutationObserver(later).observe(document.head, {
      childList: true,
      subtree: true,
    });
    document.addEventListener("load", later, true);
  };
  document.readyState === "loading"
    ? addEventListener("DOMContentLoaded", start)
    : start();
};

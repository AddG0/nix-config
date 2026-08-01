// No bundler: @decky/rollup only externalises @decky/ui to DFL, react to
// SP_REACT and @decky/api to the loader's init hook, so for a plugin this small
// the bundle's output is its input. Plain ES2020 — nothing here is transpiled.
const {
  definePlugin,
  PanelSection,
  PanelSectionRow,
  DropdownItem,
  ButtonItem,
  ConfirmModal,
  showModal,
  Field,
  Spinner,
  staticClasses,
} = DFL;

const { createElement: h, useState, useEffect, useCallback } = SP_REACT;

const manifest = { name: 'Gamescope Output' };
const API_VERSION = 2;

const internalAPIConnection =
  window.__DECKY_SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED_deckyLoaderAPIInit;
if (!internalAPIConnection) {
  throw new Error('[gamescope-output]: loader API was not initialized.');
}
const api = internalAPIConnection.connect(API_VERSION, manifest.name);
const call = api.call;

function Panel() {
  const [outputs, setOutputs] = useState([]);
  const [preferred, setPreferred] = useState('');
  const [selected, setSelected] = useState('');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [list, pref] = await Promise.all([
        call('list_outputs'),
        call('get_preferred'),
      ]);
      if (!list.ok) throw new Error(list.error);
      if (!pref.ok) throw new Error(pref.error);

      setOutputs(list.outputs);
      setPreferred(pref.preferred);
      // Fall back to the first output so Apply always has something valid to send.
      const known = list.outputs.some((o) => o.name === pref.preferred);
      setSelected(known ? pref.preferred : (list.outputs[0]?.name ?? ''));
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
          strOKButtonText: 'Restart',
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
      h(PanelSectionRow, { key: 'error' }, h(Field, { label: 'Error', bottomSeparator: 'standard' }, error)),
    );
  }

  if (outputs.length === 0) {
    rows.push(
      h(PanelSectionRow, { key: 'empty' }, h(Field, { label: 'No connected outputs' })),
    );
    return h(PanelSection, { title: 'Display' }, rows);
  }

  rows.push(
    h(
      PanelSectionRow,
      { key: 'current' },
      h(Field, { label: 'Currently set to', focusable: true }, preferred || 'Automatic'),
    ),
  );

  rows.push(
    h(
      PanelSectionRow,
      { key: 'pick' },
      h(DropdownItem, {
        label: 'Monitor',
        menuLabel: 'Run Gaming Mode on',
        rgOptions: outputs.map((o) => ({
          data: o.name,
          label: o.internal ? `${o.name} (built-in)` : o.name,
        })),
        selectedOption: selected,
        onChange: (opt) => setSelected(opt.data),
      }),
    ),
  );

  rows.push(
    h(
      PanelSectionRow,
      { key: 'apply' },
      h(
        ButtonItem,
        {
          layout: 'below',
          disabled: busy || selected === preferred,
          onClick: () =>
            confirm(
              `Move Gaming Mode to ${selected}?`,
              'Steam restarts to change monitor. Close any running game first — unsaved progress will be lost.',
              () =>
                call(
                  'set_output',
                  selected,
                  outputs.map((o) => o.name),
                ),
            ),
        },
        selected === preferred ? 'Already on this monitor' : `Switch to ${selected}`,
      ),
    ),
  );

  if (preferred) {
    rows.push(
      h(
        PanelSectionRow,
        { key: 'clear' },
        h(
          ButtonItem,
          {
            layout: 'below',
            disabled: busy,
            onClick: () =>
              confirm(
                'Go back to automatic?',
                'Gamescope picks the monitor itself. Steam restarts to apply.',
                () => call('clear_output'),
              ),
          },
          'Use automatic',
        ),
      ),
    );
  }

  return h(PanelSection, { title: 'Display' }, rows);
}

const Icon = () =>
  h(
    'svg',
    { width: '1em', height: '1em', viewBox: '0 0 24 24', fill: 'currentColor' },
    h('path', {
      d: 'M3 4h18a1 1 0 0 1 1 1v11a1 1 0 0 1-1 1h-7v2h3v2H7v-2h3v-2H3a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1zm1 2v9h16V6H4z',
    }),
  );

export default definePlugin(() => ({
  title: h('div', { className: staticClasses.Title }, 'Gamescope Output'),
  icon: h(Icon, null),
  content: h(Panel, null),
}));

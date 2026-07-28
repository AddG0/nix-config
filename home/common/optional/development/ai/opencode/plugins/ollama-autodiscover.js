// Populate provider.ollama.models from the live `ollama list` (GET /api/tags)
// so opencode's model picker always reflects what Ollama actually has pulled,
// without hardcoding model tags in config. Declared models are preserved.
export const OllamaAutodiscover = async () => ({
  config: async (config) => {
    const provider = config?.provider?.ollama;
    if (!provider) return;
    const baseURL = provider.options?.baseURL ?? "http://localhost:11434/v1";
    const tagsURL = baseURL.replace(/\/v1\/?$/, "") + "/api/tags";
    try {
      const res = await fetch(tagsURL, { signal: AbortSignal.timeout(3000) });
      if (!res.ok) return;
      const data = await res.json();
      provider.models ??= {};
      for (const m of data.models ?? []) {
        if (!m?.name || provider.models[m.name]) continue;
        provider.models[m.name] = { name: m.name };
      }
    } catch {
      // Ollama offline — leave any declared models as-is.
    }
  },
});

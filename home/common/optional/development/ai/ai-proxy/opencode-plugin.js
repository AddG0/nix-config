// Signs opencode's ai-proxy provider in with the ai-proxy helper and fills its model picker from the proxy's /v1/models.
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const run = promisify(execFile);
const provider = "@provider@";

// Per request, as the helper renews the token before it expires and opencode sessions outlive it.
const token = async () => (await run("@helper@", ["token"])).stdout;

export const AiProxy = async ({ client }) => ({
  config: async (config) => {
    const settings = config?.provider?.[provider];
    if (!settings) return;
    const url = `${settings.options.baseURL}/models`;
    try {
      const res = await fetch(url, {
        headers: { Authorization: `Bearer ${await token()}` },
        signal: AbortSignal.timeout(10000),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      settings.models ??= {};
      for (const { id } of data.data ?? []) {
        // Image models answer no chat requests.
        if (!id || id.startsWith("gpt-image") || settings.models[id]) continue;
        settings.models[id] = { name: id };
      }
    } catch (error) {
      // Startup goes on without these models; `ai-proxy status` says whether it is the login or the network.
      await client.app.log({
        body: {
          service: "ai-proxy",
          level: "warn",
          message: `cannot list models from ${url}: ${error.message}`,
        },
      });
    }
  },
  "chat.headers": async (input, output) => {
    if (input.model.providerID !== provider) return;
    output.headers.Authorization = `Bearer ${await token()}`;
  },
});

{
  pkgs,
  colors,
  fonts,
  ...
}: let
  c = colors;
  # Prepend a :root block defining stylix colors + fonts as CSS variables, which
  # the sibling .css templates reference via var(--baseNN)/var(--font-*). Using
  # real CSS vars (rather than @placeholder@ substitution) keeps the templates
  # valid CSS that prettier can format without mangling.
  themeCss = name: file:
    pkgs.writeText name ''
      :root {
        --base00: ${c.base00};
        --base01: ${c.base01};
        --base02: ${c.base02};
        --base03: ${c.base03};
        --base04: ${c.base04};
        --base05: ${c.base05};
        --base06: ${c.base06};
        --base07: ${c.base07};
        --base08: ${c.base08};
        --base09: ${c.base09};
        --base0A: ${c.base0A};
        --base0B: ${c.base0B};
        --base0C: ${c.base0C};
        --base0D: ${c.base0D};
        --base0E: ${c.base0E};
        --base0F: ${c.base0F};
        --font-sans: "${fonts.sansSerif.name}";
        --font-mono: "${fonts.monospace.name}";
      }
      ${builtins.readFile file}
    '';
in {
  plugins.lsp.servers.marksman.enable = true;

  # In-buffer prettifying of headings/tables/code — terminal-native, always on.
  # This (plus snacks.image for diagrams) is the live, as-you-type view.
  plugins.render-markdown.enable = true;

  # Inline diagram/image/math rendering via snacks' image module (the
  # snacks-native replacement for image.nvim + diagram.nvim): ```mermaid blocks
  # render as images in the buffer over Ghostty's kitty graphics protocol, with
  # a CURRENT mermaid (mmdc 11.x). Merges into the snacks settings in ../../ui.nix.
  # Needs mmdc + imagemagick on PATH — see extraPackages. This is the primary
  # mermaid path.
  plugins.snacks.settings.image.enabled = true;

  # Full-page browser preview (<leader>cp → :MarkdownPreview, open-only not
  # toggle). It's a one-shot snapshot: this old plugin's live websocket refresh
  # is broken on nvim 0.12. The maintained alternative (peek.nvim) is unusable
  # via nixpkgs — its Deno client bundle isn't built in the package — so we keep
  # this for whole-document reading and rely on render-markdown for the live view.
  plugins.markdown-preview = {
    enable = true;
    settings = {
      # Default auto_close=1 closes the preview the instant focus leaves the
      # markdown buffer (e.g. when the browser opens) — kills it almost
      # immediately. 0 keeps it open until :MarkdownPreviewStop.
      auto_close = 0;
      # Theme the browser preview from stylix (page chrome + code highlighting).
      markdown_css = "${themeCss "markdown-preview.css" ./preview.css}";
      highlight_css = "${themeCss "markdown-preview-highlight.css" ./highlight.css}";
    };
  };

  plugins.lint = {
    lintersByFt.markdown = ["markdownlint"];
    # The linter is named `markdownlint`, its package is markdownlint-cli.
    autoInstall.overrides.markdownlint = pkgs.markdownlint-cli;
  };

  extraPackages = with pkgs; [
    mermaid-cli # mmdc — Snacks.image's mermaid converter (pulls headless chromium)
    imagemagick # Snacks.image processing / rasterization
    ghostscript # gs — imagemagick's PDF rasterizer (Snacks.image PDF preview)
  ];

  keymaps = [
    {
      mode = "n";
      key = "<leader>cp";
      action = "<cmd>MarkdownPreview<cr>";
      options.desc = "Markdown preview (browser, open)";
    }
  ];
}

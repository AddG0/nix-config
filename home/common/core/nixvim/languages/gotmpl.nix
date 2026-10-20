_: {
  # Neovim maps `.tmpl` to the generic `template` ft, which has no highlighting.
  # The outer language comes from the name before `.tmpl`: `values.yaml.tmpl`
  # injects YAML around the {{ }} actions, `alert-message.tmpl` injects nothing.
  extraConfigLua = ''
    vim.filetype.add({ extension = { tmpl = "gotmpl" } })
    vim.treesitter.query.add_directive("inject-go-tmpl!", function(_, _, source, _, metadata)
      if type(source) ~= "number" then return end
      local base = vim.fs.basename(vim.api.nvim_buf_get_name(source)):match("^(.+)%.tmpl$")
      local ft = base and vim.filetype.match({ filename = base })
      metadata["injection.language"] = ft and vim.treesitter.language.get_lang(ft)
    end, { force = true })
  '';

  extraFiles."queries/gotmpl/injections.scm".text = ''
    ;; extends

    ((text) @injection.content
      (#inject-go-tmpl!)
      (#set! injection.combined))
  '';
}

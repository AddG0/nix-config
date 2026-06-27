{
  # vim-helm gives chart templates the `helm` filetype so yamlls stops choking
  # on the {{ }} Go templates; helm_ls is the LSP.
  plugins = {
    helm.enable = true;
    lsp.servers.helm_ls.enable = true;
  };
}

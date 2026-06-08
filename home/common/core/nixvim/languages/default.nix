{lib, ...}: {
  # Each language owns its full stack (LSP server + formatter + linter + DAP +
  # tools) in one file. scanPaths auto-imports every sibling, so adding a
  # language is just dropping a file here — and removing one is deleting it.
  imports = lib.custom.scanPaths ./.;
}

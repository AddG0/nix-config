{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "ai-usagebar";
  version = "1.20.2";

  src = fetchFromGitHub {
    owner = "akitaonrails";
    repo = "ai-usagebar";
    rev = "v${version}";
    hash = "sha256-33lLgD+s9Y3pN4OBLKiiCMEuI69rWdL0ODeJ+BesCBg=";
  };

  cargoHash = "sha256-Ar+D3nHDpqkOaXiBGmSDStxi/k/LEcGVywbrDlnxIgY=";

  # Both drive Claude Desktop rollback through a hardcoded /usr/bin/tar.
  checkFlags = [
    "--skip=claude_desktop::app::tests::rollback_archives_and_their_directory_are_private"
    "--skip=claude_desktop::app::tests::a_failed_restore_does_not_carry_a_terminal_escape_out_of_the_archive_path"
  ];

  meta = {
    description = "CLI and TUI reporting AI plan usage (Claude, Codex, and others) from the vendors' own quota endpoints";
    homepage = "https://github.com/akitaonrails/ai-usagebar";
    license = lib.licenses.mit;
    mainProgram = "ai-usagebar";
  };
}

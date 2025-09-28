{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    # Go language and tools
    go
    gopls # Go language server
    gotools # Includes goimports and other tools
    golangci-lint # Popular Go linter
    delve # Go debugger
    gomodifytags # Tool to modify struct field tags
    gotests # Generate Go tests
    mockgen # Generate mocks for Go interfaces
    gofumpt # Stricter gofmt
    gopkgs # List packages
    goreleaser # Release automation tool
  ];

  # Go environment variables
  home.sessionVariables = {
    GOPATH = "$HOME/go";
    GOBIN = "$HOME/go/bin";
  };

  # Add Go binaries to PATH
  home.sessionPath = [
    "$HOME/go/bin"
  ];

  # Create Go workspace directories
  home.activation.createGoDirs = ''
    mkdir -p $HOME/go/{bin,src,pkg}
  '';
}

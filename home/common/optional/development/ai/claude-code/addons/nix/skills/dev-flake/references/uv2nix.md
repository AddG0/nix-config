# uv2nix Reference

Use when the project uses `uv` for Python dependency management (has `pyproject.toml` + `uv.lock`).

## Additional Inputs

Merge these into the base flake template's `inputs`:

```nix
pyproject-nix = {
  url = "github:pyproject-nix/pyproject.nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
uv2nix = {
  url = "github:pyproject-nix/uv2nix";
  inputs = {
    nixpkgs.follows = "nixpkgs";
    pyproject-nix.follows = "pyproject-nix";
  };
};
pyproject-build-systems = {
  url = "github:pyproject-nix/build-system-pkgs";
  inputs = {
    nixpkgs.follows = "nixpkgs";
    pyproject-nix.follows = "pyproject-nix";
    uv2nix.follows = "uv2nix";
  };
};
```

## perSystem Pattern

Replace the base template's `perSystem` with this structure:

```nix
perSystem = {pkgs, config, lib, ...}: let
  workspace = inputs.uv2nix.lib.workspace.loadWorkspace {workspaceRoot = ./.;};

  # Fix packages missing build-system metadata
  pyprojectOverrides = final: prev: {
    # Package missing setuptools:
    # some-pkg = prev.some-pkg.overrideAttrs (old: {
    #   nativeBuildInputs = (old.nativeBuildInputs or []) ++ [final.setuptools];
    # });
    # Ignore missing optional CUDA/native deps on wheel packages:
    # torch = prev.torch.overrideAttrs { autoPatchelfIgnoreMissingDeps = true; };
  };

  pythonSet =
    (pkgs.callPackage inputs.pyproject-nix.build.packages {
      python = pkgs.python312;
    }).overrideScope
    (lib.composeManyExtensions [
      inputs.pyproject-build-systems.overlays.default
      (workspace.mkPyprojectOverlay {sourcePreference = "wheel";})
      pyprojectOverrides
    ]);

  # Locked virtual env for CI / packages output
  pythonEnv = pythonSet.mkVirtualEnv "project-env" workspace.deps.all;

  # Editable virtual env for development (hot-reload on source changes)
  editablePythonSet = pythonSet.overrideScope (lib.composeManyExtensions [
    (workspace.mkEditablePyprojectOverlay {root = "$REPO_ROOT";})
    (final: prev: {
      my-package = prev.my-package.overrideAttrs (old: {
        src = lib.fileset.toSource {
          root = old.src;
          fileset = lib.fileset.unions [
            (old.src + "/pyproject.toml")
            (old.src + "/src")
          ];
        };
        nativeBuildInputs =
          old.nativeBuildInputs
          ++ final.resolveBuildSystem {editables = [];};
      });
    })
  ]);
  editableEnv = editablePythonSet.mkVirtualEnv "project-dev-env" workspace.deps.all;
in {
  pre-commit.settings.hooks = {
    alejandra.enable = true;
    ruff.enable = true;
    ruff-format.enable = true;
  };

  packages.default = pythonEnv;

  devShells.default = pkgs.mkShell {
    packages = [editableEnv pkgs.uv];
    env = {
      UV_NO_SYNC = "1";
      UV_PYTHON = "${editableEnv}/bin/python";
      UV_PYTHON_DOWNLOADS = "never";
    };
    shellHook = ''
      unset PYTHONPATH
      export REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
      ${config.pre-commit.installationScript}
    '';
  };
};
```

## Conventions

- `sourcePreference = "wheel"` — prefer wheels to avoid compiling from source
- `pyprojectOverrides` — fix packages missing build-system metadata (add `setuptools`, `hatchling`, etc.) or use `autoPatchelfIgnoreMissingDeps` for optional native deps
- `editablePyprojectOverlay` — enables editable installs so source changes reflect without rebuilds
- `UV_NO_SYNC = "1"` — prevent uv from touching the Nix-managed venv
- `UV_PYTHON_DOWNLOADS = "never"` — all Python comes from Nix
- `unset PYTHONPATH` — avoid conflicts with system Python paths
- Always `follows` nixpkgs/pyproject-nix/uv2nix across the three inputs to keep one evaluation

## Customization Points

- Replace `pkgs.python312` with the desired Python version
- Replace `my-package` in the editable overlay with the actual package name from `pyproject.toml`
- Add native library paths to `LD_LIBRARY_PATH` in `shellHook` if needed (e.g., `pkgs.portaudio`, `pkgs.libsndfile`)
- Add entries to `pyprojectOverrides` as builds fail — common fixes are adding `setuptools`/`hatchling`/`flit-core` to `nativeBuildInputs`

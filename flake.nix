{
  description = "Description for the project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pre-commit-hooks.url = "github:cachix/git-hooks.nix";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.pre-commit-hooks.flakeModule
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:
        let
          typewriter-mimicker = pkgs.writeShellApplication {
            name = "typewriter-mimicker";
            runtimeInputs = [
              pkgs.stack
              pkgs.uv
            ];
            text = ''
              export TYPEWRITER_REPO_ROOT=${./.}
              exec ${./scripts/typewriter-mimicker.sh} "$@"
            '';
          };
        in
        {
          pre-commit.settings = {
            src = ./.;
            hooks = {
              nixfmt-rfc-style.enable = true;
              ruff.enable = true;
              ruff-format.enable = true;
            };
          };
          apps = {
            default = {
              type = "app";
              program = "${typewriter-mimicker}/bin/typewriter-mimicker";
            };
            typewriter-mimicker = config.apps.default;
          };
          packages = {
            default = typewriter-mimicker;
            typewriter-mimicker = typewriter-mimicker;
          };
          devShells = {
            default = pkgs.mkShellNoCC {
              buildInputs = with pkgs; [
                ghc
                haskell-language-server
                pre-commit
                python314
                ruff
                stack
                uv
                pythonManylinuxPackages.manylinux2014Package
              ];
              NIX_LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
                pkgs.stdenv.cc.cc
                pkgs.pythonManylinuxPackages.manylinux2014Package
              ];
              NIX_LD = builtins.readFile "${pkgs.stdenv.cc}/nix-support/dynamic-linker";

              shellHook = ''
                # install pre-commit hooks
                ${config.pre-commit.installationScript}

                (cd renderer && uv venv --allow-existing && . .venv/bin/activate && uv sync)
              '';
            };
          };
        };
    };
}

{
  description = "Development environment for i3c-core.";

  inputs = {
    lowrisc-nix.url = "github:lowRISC/lowrisc-nix";
    nixpkgs.follows = "lowrisc-nix/nixpkgs";
    flake-utils.follows = "lowrisc-nix/flake-utils";
  };

  nixConfig = {
    extra-substituters = ["https://nix-cache.lowrisc.org/public/"];
    extra-trusted-public-keys = ["nix-cache.lowrisc.org-public-1:O6JLD0yXzaJDPiQW1meVu32JIDViuaPtGDfjlOopU7o="];
  };

  outputs = inputs: inputs.flake-utils.lib.eachDefaultSystem (system: let

    pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = [
        (final: prev: {
          buildFHSEnvOverlay = final.callPackage inputs.lowrisc-nix.lib.buildFHSEnvOverlay {};
        })
      ];
    };

    verilator' = pkgs.verilator.overrideAttrs rec {
      version = "5.024";
      src = pkgs.fetchFromGitHub {
        owner = "verilator";
        repo = "verilator";
        rev = "v${version}";
        sha256 = "sha256-It1PEhS36L/n2r6HsDrkrk/kuz86IXLxsIYhFk/VRGc=";
      };
      patches = [];
      doCheck = false;
    };

    verilator-cond-coverage = pkgs.verilator.overrideAttrs rec {
      version = "5.030-cond-coverage";
      src = pkgs.fetchFromGitHub {
        owner = "antmicro";
        repo = "verilator";
        rev = "f338b6f603f02a9ea9ceeb40ccd1ce14cbdf9e07";
        sha256 = "sha256-hnsftIWubq0mzrjSPfXfxVlWqVXtQVNlVSq2kcwIMU4=";
      };
      patches = [];
      doCheck = false;
    };

    activateEnvUV = ''
      # Provision the python venv using UV (if it does not already exist), and activate it.
      if [[ -f "pyproject.toml" ]]; then
        [[ -d ".venv" ]] || (uv venv && uv sync)
        [[ -d ".venv" ]] && . .venv/bin/activate
      fi
    '';

    simPkgs = _ :
      (with pkgs; [
        # FOSS
        gcc
        zlib
        uv
        python311
        verible
        verilator'
        gtkwave
        surfer
      ]);

    covPkgs = _ :
      (with pkgs; [
        # FOSS
        uv
        python311
        verilator-cond-coverage
      ]);

    mkShell = targetPkgs: (pkgs.buildFHSEnvOverlay {
      pname = "caliptra-i3c";
      version = "dev";
      inherit targetPkgs;
      extraOutputsToInstall = ["dev"];
      profile = ''
        ${activateEnvUV}
      '';
      runScript = "\${SHELL:-bash}";
    }).env;


  in

    {
      devShells = rec {
         default = sim;
         sim = mkShell simPkgs;
         cov = mkShell covPkgs;
      };
    }

  );
}

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , uv2nix
    , pyproject-nix
    , pyproject-build-systems
    , ...
    }: flake-utils.lib.eachDefaultSystem (system:
    let
      inherit (nixpkgs) lib;

      pkgs = nixpkgs.legacyPackages.${system};

      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

      overlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };

      baseSet = pkgs.callPackage pyproject-nix.build.packages {
        python = pkgs.python313;
      };

      pythonSet = baseSet.overrideScope (
        lib.composeManyExtensions [
          pyproject-build-systems.overlays.default
          overlay
        ]
      );

      venv = pythonSet.mkVirtualEnv "fastapi-sse-env" workspace.deps.default;
    in
    {
      packages = {
        default = pkgs.writeShellApplication {
          name = "fastapi-sse";

          runtimeInputs = [ venv ];

          text = ''
            uvicorn fastapi_sse.main:app --host=0.0.0.0
          '';
        };
      } // lib.optionalAttrs pkgs.stdenv.isLinux {
        containerImage = pkgs.dockerTools.streamLayeredImage {
          name = "ghcr.io/buurro/fastapi-sse";
          tag = pythonSet.fastapi-sse.version;
          contents = [
            venv
            pkgs.busybox
          ];
          config = {
            Cmd = [ "uvicorn" "fastapi_sse.main:app" "--host=0.0.0.0" ];
            ExposedPorts = {
              "8000/tcp" = { };
            };
          };
        };
      };
    });
}

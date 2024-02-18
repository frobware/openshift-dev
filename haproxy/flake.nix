{
  description = "A flake offering various versions of HAProxy, built in the style of OpenShift Ingress.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }: let
    forAllSystems = function: nixpkgs.lib.genAttrs [ "aarch64-linux" "x86_64-linux" ] (
      system: function system
    );
  in {
    checks = forAllSystems (system: {
      build = self.packages.${system}.default;
    });

    devShells = forAllSystems (system: let
      pkgs = (import nixpkgs { inherit system; });
    in {
      default = pkgs.mkShell {
        buildInputs = [
          self.packages.${system}.default.buildInputs
        ];
        nativeBuildInputs = [
          pkgs.pkg-config
        ];
        shellHook = ''
          export SRC=${self.packages.${system}.default.src}
          echo "HAProxy source is at: $SRC"
          # Setting NIX_PATH explicitly so that nix-prefetch-url can
          # find the nixpkgs location. This is essential because a
          # pure shell does not inherit NIX_PATH from the parent
          # environment.
          export NIX_PATH=nixpkgs=${pkgs.path}
        '';
      };
    });

    overlays = {
      default = (final: prev: let
        haproxyVersions = import ./versions.nix { pkgs = prev; };
      in haproxyVersions);
    };

    packages = forAllSystems (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
    in {
      default = pkgs.ocp-haproxy-2_8_6;
    });
  };
}

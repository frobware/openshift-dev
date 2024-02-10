{
  description = "A flake offering various versions of HAProxy, built in the style of OpenShift Ingress.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }: let
    forAllSystems = function: nixpkgs.lib.genAttrs [ "aarch64-linux" "x86_64-linux" ] (
      system: function system nixpkgs.legacyPackages.${system}
    );
  in {
    devShells = forAllSystems (system: pkgs: {
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

    overlays = let
      haproxyOverlay = final: prev: {
        ocp-haproxy = self.packages.${final.system};
      };
    in {
      default = haproxyOverlay;
    };

    packages = forAllSystems (system: pkgs: let
      haproxyVersions = import ./versions.nix { inherit pkgs; };
    in haproxyVersions // {
      default = haproxyVersions.ocp-haproxy-2_8_5;
    });
  };
}

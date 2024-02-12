{
  description = "A flake providing multiple versions of the OpenShift client (oc).";

  outputs = { self, nixpkgs }:
  let
    forAllSystems = function: nixpkgs.lib.genAttrs [ "aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux" ] (
      system: function system nixpkgs.legacyPackages.${system}
    );
  in {
    devShells = forAllSystems (system: pkgs: {
      default = pkgs.mkShell {
        buildInputs = [
          pkgs.nix
          pkgs.nix-prefetch
        ];
        packages = [
          (pkgs.writeScriptBin "fetch-hash" (builtins.readFile ./fetch-hash.sh))
        ];
        shellHook = ''
          # Setting NIX_PATH explicitly so that nix-prefetch-url can
          # find the nixpkgs location. This is essential because a
          # pure shell does not inherit NIX_PATH from the parent
          # environment.
          export NIX_PATH=nixpkgs=${pkgs.path}
        '';
      };
    });

    overlays = let
      ocOverlay = final: prev: {
        openshift-clients = self.packages.${final.system};
      };
    in {
      default = ocOverlay;
    };

    packages = forAllSystems (system: pkgs: let
      openshift-clients = import ./versions.nix { inherit system pkgs; };
    in openshift-clients // {
      default = openshift-clients.oc_4_14;
    });
  };
}

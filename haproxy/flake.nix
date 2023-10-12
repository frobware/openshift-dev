{
  description = "A flake providing multiple versions of HAProxy built for OpenShift Ingress.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
  let
    supportedSystems = [ "aarch64-linux" "x86_64-linux" ];

    generateHAProxyPackagesForSystem = system:
    let
      packageSet = import ./packages.nix {
        system = system;
        inputs = { inherit nixpkgs; };
      };
    in
    packageSet;

    dynamicOverlays = nixpkgs.lib.genAttrs supportedSystems (system: final: prev:
    let
      packageSet = generateHAProxyPackagesForSystem system;
    in builtins.listToAttrs (map (name: { inherit name; value = packageSet.${name}; }) (builtins.attrNames packageSet)));

    forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
      pkgs = self.inputs.nixpkgs.legacyPackages.${system};
    });

    setDefaultPackageForSystem = system: self.packages.${system}.haproxy_2_6_13;
  in {
    packages = nixpkgs.lib.genAttrs supportedSystems generateHAProxyPackagesForSystem;
    overlays = nixpkgs.lib.genAttrs supportedSystems (system: final: prev: dynamicOverlays.${system} final prev);

    defaultPackage = nixpkgs.lib.genAttrs supportedSystems setDefaultPackageForSystem;

    devShells = forEachSupportedSystem ({ pkgs }: {
      default = pkgs.mkShell {
        buildInputs = [ ];
        packages = [ ];
        shellHook = ''
          # Setting NIX_PATH explicitly so that nix-prefetch-url can
          # find the nixpkgs location. This is essential because a
          # pure shell does not inherit NIX_PATH from the parent
          # environment.
          export NIX_PATH=nixpkgs=${pkgs.path}
        '';
      };
    });
  };
}

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
  in {
    packages = nixpkgs.lib.genAttrs supportedSystems generateHAProxyPackagesForSystem;
    overlays = nixpkgs.lib.genAttrs supportedSystems (system: final: prev: dynamicOverlays.${system} final prev);
  };
}

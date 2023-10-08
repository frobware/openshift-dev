{
  description = "A flake providing multiple versions of the OpenShift client utility.";

  outputs = { self, nixpkgs }:
  let
    supportedSystems = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];

    generateVersionedOpenShiftPackagesForSystem = system:
    let
      packageSet = import ./packages.nix {
        system = system;
        inputs = { inherit nixpkgs; };
      };
    in
    packageSet;

    dynamicOverlays = nixpkgs.lib.genAttrs supportedSystems (system: final: prev:
      let
        packageSet = generateVersionedOpenShiftPackagesForSystem system;
      in
      builtins.listToAttrs (map (name: { inherit name; value = packageSet.${name}; }) (builtins.attrNames packageSet))
    );
  in
  {
    packages = nixpkgs.lib.genAttrs supportedSystems generateVersionedOpenShiftPackagesForSystem;
    overlays = dynamicOverlays;
  };
}

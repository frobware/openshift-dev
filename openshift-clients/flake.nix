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

    forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
      pkgs = self.inputs.nixpkgs.legacyPackages.${system};
    });

    setDefaultPackageForSystem = system: self.packages.${system}.oc_4_13;
  in {
    packages = nixpkgs.lib.genAttrs supportedSystems generateVersionedOpenShiftPackagesForSystem;
    overlays = dynamicOverlays;
    defaultPackage = nixpkgs.lib.genAttrs supportedSystems setDefaultPackageForSystem;
    devShells = forEachSupportedSystem ({ pkgs }: {
      default = pkgs.mkShell {
        buildInputs = [ pkgs.nix-prefetch pkgs.nix ];
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
  };
}

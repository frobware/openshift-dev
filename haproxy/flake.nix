{
  description = "A flake offering various versions of HAProxy, built in the style of OpenShift Ingress.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }: let
    forAllSystems = function: nixpkgs.lib.genAttrs [ "aarch64-linux" "x86_64-linux" ] (
      system: function system
    );

    haproxyOverlay = final: prev: let
      makeHAProxyPackage = { version, sha256, patches ? [], debug ? false, target ? "linux-glibc" }: prev.callPackage ./package.nix {
        inherit version sha256 debug patches target;
      };

      haproxyVersions = {
        "2.6.13" = {
          sha256 = "0hsj7zv1dxcz9ryr7hg1bczy7h9f488x307j5q9mg9mw7lizb7yn";
          patches = [
            ./patches/2.6.13/0001-BUG-MAJOR-http-reject-any-empty-content-length-heade.patch
            ./patches/2.6.13/0001-BUG-MINOR-fd-always-remove-late-updates-when-freeing.patch
          ];
        };
        "2.6.14" = {
          sha256 = "sha256-vT3Z+mA5HKCeEiXhrDFj5FvoPD9U8v12owryicxuT9Q=";
        };
        "2.6.15" = {
          sha256 = "sha256-QfjhaV6S+v3/45aQpomT8aD19/BpMamemhU/dJ6jnP0=";
        };
        "2.8.3" = {
          sha256 = "sha256-nsxv/mepd9HtJ5EHu9q3kNc64qYmvDju4j+h9nhqdZ4=";
        };
        "2.8.5" = {
          sha256 = "sha256-P1RZxaWOCzQ6MurvftW+2dP8KdiqnhSzbJLJafwqYNk=";
        };
        "2.8.6" = {
          sha256 = "sha256-n9A0NovmaIC9hqMAwT3AO8E1Ie4mVIgN3fGSeFqijVE=";
        };
      };

      versionsList = builtins.attrNames haproxyVersions;

      haproxyPackages = builtins.listToAttrs (nixpkgs.lib.flatten (nixpkgs.lib.mapAttrsToList (version: value: let
        releaseName = "ocp-haproxy-${builtins.replaceStrings ["."] ["_"] version}";
        debugName = "ocp-haproxy-debug-${builtins.replaceStrings ["."] ["_"] version}";
        releasePackage = makeHAProxyPackage { inherit version; sha256 = value.sha256; patches = value.patches or []; debug = false; };
        debugPackage = makeHAProxyPackage { inherit version; sha256 = value.sha256; patches = value.patches or []; debug = true; };
      in [
        { name = releaseName; value = releasePackage; }
        { name = debugName; value = debugPackage; }
      ]) haproxyVersions));

      haproxyMeta = final.stdenv.mkDerivation {
        name = "ocp-haproxy-meta";
        buildInputs = [ final.makeWrapper ];
        buildCommand = let
          createSymlinkCommand = version: let
            packageName = "ocp-haproxy-${builtins.replaceStrings ["."] ["_"] version}";
            binDir = prev.lib.getBin (haproxyPackages.${packageName});
          in ''
            ln -s ${binDir}/bin/ocp-haproxy $out/bin/ocp-haproxy-${version}
          '';
          symlinkCommands = builtins.concatStringsSep "\n" (map createSymlinkCommand versionsList);
        in ''
          mkdir -p $out/bin
          ${symlinkCommands}
        '';
      };

      haproxyMetaDebug = final.stdenv.mkDerivation {
        name = "ocp-haproxy-debug-meta";
        buildInputs = [ final.makeWrapper ];
        buildCommand = let
          createSymlinkCommand = version: let
            packageName = "ocp-haproxy-debug-${builtins.replaceStrings ["."] ["_"] version}";
            binDir = prev.lib.getBin (haproxyPackages.${packageName});
          in ''
            ln -s ${binDir}/bin/ocp-haproxy-debug $out/bin/ocp-haproxy-debug-${version}
            ln -s ${binDir}/bin/ocp-haproxy-gdb $out/bin/ocp-haproxy-gdb-${version}
          '';
          symlinkCommands = builtins.concatStringsSep "\n" (map createSymlinkCommand versionsList);
        in ''
          mkdir -p $out/bin
          ${symlinkCommands}
        '';
      };
    in haproxyPackages // { ocp-haproxy-meta = haproxyMeta; ocp-haproxy-debug-meta = haproxyMetaDebug; };
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
      default = haproxyOverlay;
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

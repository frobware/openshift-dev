{ system, inputs, ... }:

with inputs.nixpkgs;
let
  versions = {
    "2.2.29" = {
      sha256 = "1e41f49674fbf5663b55c5f7919a7d05e480730653f2bcdec384b8836efc1fb0";
    };
    "2.4.22" = {
      sha256 = "0895340b36b704a1dbb25fea3bbaee5ff606399d6943486ebd7f256fee846d3a";
    };
    "2.6.13" = {
      sha256 = "0hsj7zv1dxcz9ryr7hg1bczy7h9f488x307j5q9mg9mw7lizb7yn";
      patches = [
        ./2.6.13/0001-BUG-MAJOR-http-reject-any-empty-content-length-heade.patch
        ./2.6.13/0001-BUG-MINOR-fd-always-remove-late-updates-when-freeing.patch
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
  };

  buildHaproxyVersionFor = system: version: sha256: patches:
  let
    pkgs = inputs.nixpkgs.legacyPackages.${system};
    package = pkgs.callPackage ./package.nix {
      inherit version sha256 patches;
    };
  in
  {
    "${version}" = package.buildHAProxy;
    "${version}_debug" = package.buildHAProxyDebug;
  };
in
builtins.listToAttrs (lib.flatten (lib.mapAttrsToList (version: value: [
  {
    name = "ocp_haproxy_" + lib.replaceStrings ["."] ["_"] version;
    value = (buildHaproxyVersionFor system version value.sha256 (value.patches or []))."${version}";
  }
  {
    name = "ocp_haproxy_" + builtins.replaceStrings ["."] ["_"] version + "_debug";
    value = (buildHaproxyVersionFor system version value.sha256 (value.patches or []))."${version}_debug";
  }
]) versions))

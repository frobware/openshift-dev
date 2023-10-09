{ system, inputs, ... }:

with inputs.nixpkgs;
let
  versions = {
    "4.10.64" = {
      sha256 = {
        aarch64-darwin = "sha256-LkegZQWW6Bh6PalCeRb7PGolH+rBeNLIDSm3Z3AW8C0=";
        aarch64-linux = "sha256-aqGFDxpK8rd4rY2bWdppQQu5R2ZnIjYc4gZJ6nkwKuk=";
        x86_64-darwin = "sha256-t9Dacdck5fhdYrRPJDis84buNd0G6Nnx5Xxr6Cqhgu0=";
        x86_64-linux = "sha256-b4YwPHv+WR83JH0Jl2q8jWy+xttp0VuCAi+s0G9o5As=";
      };
    };
    "4.11.46" = {
      sha256 = {
        aarch64-darwin = "sha256-em/JEc8xYXvrLM3+/06/RAxchQnLUOn7DKfVuEe6oKs=";
        aarch64-linux = "sha256-DigbKwfowDhz256UxP0hLpJPsE1JPjk3nBTuAlZrMGE=";
        x86_64-darwin = "sha256-zuQ40HIxIugq8oKJjxHJ2aVgBMaMSyN9laCMSD70JTw=";
        x86_64-linux = "sha256-XOj0bKLYMd3qfPXD5vS0QyHnImcSpykAQQYK8WThs5g=";
      };
    };
    "4.12.28" = {
      sha256 = {
        aarch64-darwin = "sha256-i304P20k7TnRHrVGg8BPFign9VA/jAuQ1vxu3mr51Jo=";
        aarch64-linux = "sha256-7Qkxaqy9iiiQBSZdKo8kBZr1uAAb7K5RPNndgxghhrU=";
        x86_64-darwin = "sha256-cn2XYdBESVyZHKOcJmlDoqhTTf80VFIMmS1XZR0VXlU=";
        x86_64-linux = "sha256-8jF0gn5TcNIeHevr1l4Dj9oq2dhfZs/jGiGu71bhDec=";
      };
    };
    "4.13.14" = {
      sha256 = {
        aarch64-darwin = "sha256-Rg4Syj6DEANwgCQ5qH6ELCpDPRzEiEADHCdg8xD1pyQ=";
        aarch64-linux = "sha256-18iQWQ3xYwmfms5tVQSjj0uwgxgKgYQE5qMJ6RkfhZE=";
        x86_64-darwin = "sha256-xqQ9cLRn0RjUd/14d0SCrkkf/QOJDHtb1nfNJTNDO/U=";
        x86_64-linux = "sha256-k2dFfHHNL1ztV3nMvcjosTdqWiyCMV3QB6D1tesrqsE=";
      };
    };
  };

  systemFilenameMap = {
    x86_64-linux = "openshift-client-linux";
    aarch64-linux = "openshift-client-linux-arm64";
    x86_64-darwin = "openshift-client-mac";
    aarch64-darwin = "openshift-client-mac-arm64";
  };

  buildOpenShiftClientVersionFor = system: version: sha256: filename:
  inputs.nixpkgs.legacyPackages.${system}.callPackage ./default.nix {
    inherit version sha256 filename;
  };
in
builtins.listToAttrs (lib.mapAttrsToList (version: versionData: {
  name = "oc_" + lib.replaceStrings ["."] ["_"] (lib.versions.majorMinor version);
  value = buildOpenShiftClientVersionFor system version versionData.sha256.${system} systemFilenameMap.${system};
}) versions)

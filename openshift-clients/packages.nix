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
    "4.13.13" = {
      sha256 = {
        aarch64-darwin = "sha256-oXwHfW3UCJhX5JDLQYfbOcbCG4ZTeMIA2mKcV+b/FdE=";
        aarch64-linux = "sha256-CUoh3+wlkvcwW35ZWIjce+7qsviWK2uvUowhWkSLm5E=";
        x86_64-darwin = "sha256-7gyC2eK7T3iroo9eILbWV/ORJNcUjgRP/2SvaTTAIwE=";
        x86_64-linux = "sha256-GLB1dsKeyQW+0JlyhRDy47cTexS8PUSJq3wjl7ACZgI=";
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

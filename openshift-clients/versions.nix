{ system, pkgs, ... }:

with pkgs;
let
  versions = {
    "4.10.67" = {
      sha256 = {
        aarch64-darwin = "sha256-b5KfpzqOjVH1Z3I47Ky7wFLYYTIHwDGpWxajA1FeOoY=";
        aarch64-linux = "sha256-v33n+cBiV26vFUL0+rbRR/HGtqII/sr0HDH7mUds8j8=";
        x86_64-darwin = "sha256-C2z1bVgD0+aIg4a9C+XCBRkMXU7hdQ8VO336/FuBf3A=";
        x86_64-linux = "sha256-WBec6o+EWLyqMBspI/DuKVxEzkVK7vs0Zi+KR4lZP3Y=";      };
    };
    "4.11.58" = {
      sha256 = {
        aarch64-darwin = "sha256-CSj4JqOWntxJDHxUVMH6SmREhlvPK0esVRbvLqCrLpg=";
        aarch64-linux = "sha256-at3wLmYBmT4jqS6ENrJSwh6O9AGQipPVm2SI5vjnc6Q=";
        x86_64-darwin = "sha256-sV1v6NEc2Ec8FZA4CNxfv4FZuGNS4HqqtgT1UR1lSB8=";
        x86_64-linux = "sha256-gL7nAmNta9hJ6nuA69fTCkSLWJI8GKRehMHz59Edcis=";      };
    };
    "4.12.49" = {
      sha256 = {
        aarch64-darwin = "sha256-dqCmMaJTMKFRQ7bwKc9fRB3l3xXUQEdNbbZt4GzU9GI=";
        aarch64-linux = "sha256-65vNTUH55T7tkhJ4WZUYGfsxqL6LfsiIxpBSQ5XDcGg=";
        x86_64-darwin = "sha256-Q1SvWNofHq1gfSNrk7UKo+p5XjC3Tw6UTUYtOFphMfM=";
        x86_64-linux = "sha256-s/aGAzNIi0/puliwCal++VOqaygdwkJSB1hXcnPGypg=";      };
    };
    "4.13.33" = {
      sha256 = {
        aarch64-darwin = "sha256-/Rfz8xppCv7srXPqEiJZqlrwvxljgT3r3zwCFdY+g/E=";
        aarch64-linux = "sha256-pqFMz+Z0n1OFWm3bE3GUd8qj05IP8VZVYNKOVey+Z34=";
        x86_64-darwin = "sha256-z27LquIjm5V0aazHuw++pv97Nmd1HlAicLhG7oU37+Y=";
        x86_64-linux = "sha256-jAkWqHs36ojHEUdrd0wsxroYZKmuh3H+1abhfj+2ris=";      };
    };
    "4.14.12" = {
      sha256 = {
        aarch64-darwin = "sha256-oUCds9jCbUTuPCQPeyMFUGODvjy38I5bocoh7AVGwe0=";
        aarch64-linux = "sha256-18lqZ+d/bnFqZv10B84EsvmzfveQK4XeaML4RvV8BOA=";
        x86_64-darwin = "sha256-KoD/9lsE3kuJl96k3BYVAjeJIESQW2zRO1RjTPsqSQ8=";
        x86_64-linux = "sha256-4hLzoXJnkIo7yYRwnWp15x5hviVz8JNfO92d08Kv89I=";    };
    };
  };

  systemFilenameMap = {
    x86_64-linux = "openshift-client-linux";
    aarch64-linux = "openshift-client-linux-arm64";
    x86_64-darwin = "openshift-client-mac";
    aarch64-darwin = "openshift-client-mac-arm64";
  };

  buildOpenShiftClientVersionFor = system: version: sha256: filename:
  pkgs.callPackage ./package.nix {
    inherit version sha256 filename;
  };
in
builtins.listToAttrs (lib.mapAttrsToList (version: versionData: {
  name = "oc_" + lib.replaceStrings ["."] ["_"] (lib.versions.majorMinor version);
  value = buildOpenShiftClientVersionFor system version versionData.sha256.${system} systemFilenameMap.${system};
}) versions)

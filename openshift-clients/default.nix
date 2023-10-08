{ lib, fetchurl, installShellFiles, stdenv, version, sha256, filename }:

stdenv.mkDerivation rec {
  inherit version sha256 filename;

  pname = "oc";

  src = fetchurl {
    url = "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${version}/${filename}.tar.gz";
    sha256 = "${sha256}";
  };

  nativeBuildInputs = [ installShellFiles ];

  phases = " unpackPhase installPhase fixupPhase postInstall ";

  unpackPhase = ''
    runHook preUnpack
    mkdir ${pname}
    tar -C ${pname} -xzf $src
  '';

  installPhase = ''
    runHook preInstall
    install -D ${pname}/oc $out/bin/oc-${lib.versions.majorMinor version}
  '';

  fixupPhase = ''
    if [[ "$(uname -m)" = "x86_64" ]] && [[ "$(uname -s)" = "Linux" ]] ; then
      patchelf --set-interpreter $(cat $NIX_CC/nix-support/dynamic-linker) $out/bin/oc-${lib.versions.majorMinor version}
    fi
  '';

  postInstall = ''
    # Generate and install the Bash completion file
    $out/bin/oc-${lib.versions.majorMinor version} completion bash > oc-${lib.versions.majorMinor version}.bash
    installShellCompletion --bash --name oc-${lib.versions.majorMinor version} oc-${lib.versions.majorMinor version}.bash

    # Generate and install the Zsh completion file
    $out/bin/oc-${lib.versions.majorMinor version} completion zsh > _oc-${lib.versions.majorMinor version}
    installShellCompletion --zsh --name _oc-${lib.versions.majorMinor version} _oc-${lib.versions.majorMinor version}

    # Replace the compdef line
    substituteInPlace $out/share/zsh/site-functions/_oc-${lib.versions.majorMinor version} \
    --replace "#compdef oc" "#compdef oc-${lib.versions.majorMinor version}" \
    --replace "compdef _oc oc" "compdef _oc oc-${lib.versions.majorMinor version}"
  '';
}

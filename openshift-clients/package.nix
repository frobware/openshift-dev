{ fetchurl, installShellFiles, stdenv, version, sha256, filename }:

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
    install -D ${pname}/oc $out/bin/oc
  '';

  fixupPhase = ''
    if [[ "$(uname -m)" = "x86_64" ]] && [[ "$(uname -s)" = "Linux" ]] ; then
      patchelf --set-interpreter $(cat $NIX_CC/nix-support/dynamic-linker) $out/bin/oc
    fi
  '';

  postInstall = ''
    # Generate and install the Bash completion file
    $out/bin/oc completion bash > oc.bash
    installShellCompletion --bash --name oc oc.bash

    # Generate and install the Zsh completion file
    $out/bin/oc completion zsh > _oc
    installShellCompletion --zsh --name _oc _oc
  '';
}

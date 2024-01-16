{ lib, fetchurl, pkgs, stdenv, version, sha256, patches, target ? "linux-glibc" }:

let
  print-compiler-includes = pkgs.writeScriptBin "nix-print-compiler-includes" "${builtins.readFile ./nix-print-compiler-includes.pl}";

  commonMakeFlags = [
    "CPU=generic"
    "TARGET=${target}"
    "USE_CRYPT_H=1"
    "USE_GETADDRINFO=1"
    "USE_LINUX_TPROXY=1"
    "USE_OPENSSL=1"
    "USE_PCRE=1"
    "USE_REGPARM=1"
    "USE_ZLIB=1"
  ];

  commonBuild = let
    source = fetchurl {
      url = "https://www.haproxy.org/download/${lib.versions.majorMinor version}/src/haproxy-${version}.tar.gz";
      sha256 = sha256;
    };
  in {
    inherit version sha256 patches;
    pname = "ocp-haproxy";
    src = source;

    buildInputs = with pkgs; [
      libxcrypt
      openssl_3
      pcre
      zlib
    ];

    nativeBuildInputs = [
      print-compiler-includes
      pkgs.bear
    ];

    enableParallelBuilding = true;
  };

  buildHAProxy = stdenv.mkDerivation (commonBuild // {
    installPhase = ''
      install -D -m 0755 haproxy $out/bin/ocp-haproxy-${version}
    '';

    makeFlags = commonMakeFlags;
  });

  buildHAProxyDebug = let
    source = commonBuild;
  in pkgs.stdenv.mkDerivation (source // rec {
    dontStrip = true;

    makeFlags = commonMakeFlags ++ [
      "\"DEBUG_CFLAGS=-g -ggdb3 -Og -fno-omit-frame-pointer -fno-inline\""
      "V=1"
    ];

    buildPhase = ''
      ${pkgs.bear}/bin/bear -- make -j ${lib.concatStringsSep " " makeFlags}
    '';

    installPhase = ''
      mkdir -p $out/bin $out/src-${version}
      install -m 0755 haproxy $out/bin/ocp-haproxy-${version}-g
      tar xf ${source.src} -C $out/src-${version} --strip-components=1
      echo "directory $out/src-${version}" > $out/.gdbinit
      # Create a wrapper script to invoke gdb with the .gdbinit file.
      echo '#!/usr/bin/env bash' > $out/bin/ocp-haproxy-${version}-gdb
      echo "${pkgs.gdb}/bin/gdb -x $out/.gdbinit \"\$@\"" >> $out/bin/ocp-haproxy-${version}-gdb
      chmod 755 $out/bin/ocp-haproxy-${version}-gdb
      ${pkgs.perl}/bin/perl ${print-compiler-includes}/bin/nix-print-compiler-includes --clangd > $out/src-${version}/.clangd
      echo "    - -I$out/src-${version}/include" >> $out/src-${version}/.clangd
      install -m 0444 compile_commands.json $out/src-${version}/compile_commands.json
    '';
  });
in
{
  buildHAProxy = buildHAProxy;
  buildHAProxyDebug = buildHAProxyDebug;
}

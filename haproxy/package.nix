{ lib, fetchurl, pkgs, stdenv, version, sha256, patches, target ? "linux-glibc" }:

let
  print-compiler-includes = pkgs.writeScriptBin "print-compiler-includes" "${builtins.readFile ./print-compiler-includes.pl}";

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
      pkgs.bear
      pkgs.jq

      print-compiler-includes
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
      package="haproxy-${version}"
      mkdir -p $out/bin $out/share/$package
      install -m 0755 haproxy $out/bin/ocp-$package-g
      tar xf ${source.src} -C $out/share
      # Create a sentinel file for Emacs project.el.
      touch $out/share/$package/.project
      echo "directory $out/share/$package/src" > $out/share/$package/gdbinit
      echo '#!/usr/bin/env bash' > $out/bin/ocp-$package-gdb
      echo "${pkgs.gdb}/bin/gdb -x $out/share/$package/gdbinit \"\$@\"" >> $out/bin/ocp-$package-gdb
      chmod 755 $out/bin/ocp-$package-gdb
      ${pkgs.perl}/bin/perl ${print-compiler-includes}/bin/print-compiler-includes --clangd > $out/share/$package/.clangd
      echo "    - -I$out/share/$package/include" >> $out/share/$package/.clangd
      # Replace references to the ephemeral /build directory.
      ${pkgs.jq}/bin/jq '[.[] | .directory |= gsub("/build/" + "'"$package"'"; "'"$out/share/$package"'") | .file |= gsub("/build/" + "'"$package"'"; "'"$out/share/$package"'") | .output |= gsub("/build/" + "'"$package"'"; "'"$out/share/$package"'")]' compile_commands.json > "$out/share/$package/compile_commands.json"
    '';
  });
in
{
  buildHAProxy = buildHAProxy;
  buildHAProxyDebug = buildHAProxyDebug;
}

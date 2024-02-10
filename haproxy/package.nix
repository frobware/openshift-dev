{ fetchurl, pkgs, stdenv, version, sha256, patches, target ? "linux-glibc", debug ? false }:

let
  print-compiler-includes = pkgs.writeScriptBin "print-compiler-includes" "${builtins.readFile ./print-compiler-includes.pl}";
  bear = if debug then "${pkgs.bear}/bin/bear --" else "";

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

  src = fetchurl {
    url = "https://www.haproxy.org/download/${pkgs.lib.versions.majorMinor version}/src/haproxy-${version}.tar.gz";
    inherit sha256;
  };

  commonBuildAttrs = {
    inherit version patches src;
    pname = "ocp-haproxy";
    buildInputs = with pkgs; [
      libxcrypt
      openssl_3
      pcre
      zlib
    ];
    enableParallelBuilding = true;
  };

  buildHAProxy = stdenv.mkDerivation (commonBuildAttrs // rec {
    name = "ocp-haproxy-${version}${pkgs.lib.optionalString debug "-debug"}";

    dontStrip = debug;
    hardeningDisable = if debug then [ "all" ] else [];

    debugMakeFlags = if debug then [
      "\"DEBUG_CFLAGS=-g -ggdb3 -O0 -fno-omit-frame-pointer -fno-inline\""
      "V=1"
    ] else [];

    makeFlags = commonMakeFlags ++ debugMakeFlags;

    buildPhase = ''
      ${bear} make -j ${pkgs.lib.concatStringsSep " " makeFlags}
    '';

    installPhase = if debug then ''
      package="haproxy-${version}"
      mkdir -p $out/bin $out/share/$package
      install -m 0755 haproxy $out/bin/ocp-$package-debug
      tar xf ${src} -C $out/share
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
    '' else ''
      install -D -m 0755 haproxy $out/sbin/ocp-haproxy-${version}
    '';
  });
in buildHAProxy

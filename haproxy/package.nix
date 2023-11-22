{ lib, fetchurl, pkgs, stdenv, version, sha256, patches, target ? "linux-glibc" }:

let
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

    enableParallelBuilding = true;
  };

  buildHAProxy = stdenv.mkDerivation (commonBuild // {
    installPhase = ''
      install -D -m 0755 haproxy $out/sbin/ocp-haproxy-${version}
    '';

    makeFlags = commonMakeFlags;
  });

  buildHAProxyDebug = let
    source = commonBuild;
  in pkgs.stdenv.mkDerivation (source // {
    dontStrip = true;

    installPhase = ''
      mkdir -p $out/sbin $out/src
      install -m 0755 haproxy $out/sbin/ocp-haproxy-${version}-g
      tar xvpf ${source.src} -C $out/src --strip-components=1
    '';

    preBuild = ''
      makeFlagsArray+=(DEBUG_CFLAGS="-g -ggdb3 -O0 -fno-omit-frame-pointer -fno-inline")
    '';

    makeFlags = commonMakeFlags ++ [ "V=1" ];
  });
in
{
  buildHAProxy = buildHAProxy;
  buildHAProxyDebug = buildHAProxyDebug;
}

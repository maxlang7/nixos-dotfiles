# This Nix expression builds and installs the Ingrid crossword app on NixOS

{ lib, stdenv, fetchurl, makeWrapper, nss, xorg, glibc, mesa, vulkan-loader }:

stdenv.mkDerivation rec {
  pname = "ingrid";
  version = "1.0"; # Replace with the actual version if known

  # Replace with the actual URL to the tarball you downloaded
  src = fetchurl {
    url = "https://releases.ingrid.cx/download/tar";  # Path to your local Ingrid tarball
    sha256 = "a2946546c09ababe35885635c04ade3c0c5d2163a8b22cc6362b0b2385be47ea";  # Replace with the actual SHA256 hash of your tarball
  };
  
  # Specify unpacking method manually
  unpackPhase = ''
    tar -xvzf $src -C $out
  '';

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [
    nss
    xorg.libX11
    xorg.libXrandr
    xorg.libXext
    xorg.libxcb
    glibc
    mesa
    vulkan-loader
  ];

  # Install phase
  installPhase = ''
    mkdir -p $out/bin
    cp -r * $out
    makeWrapper $out/Ingrid $out/bin/ingrid \
      --set LD_LIBRARY_PATH "${lib.makeLibraryPath buildInputs}"
  '';

  meta = with lib; {
    description = "Crossword-solving app Ingrid";
    homepage = "https://example.com";  # Replace with the actual homepage if known
    license = licenses.mit;  # Update with the actual license if different
    maintainers = with maintainers; [ yourGitHubUsername ];  # Replace with your username if maintaining
  };
}

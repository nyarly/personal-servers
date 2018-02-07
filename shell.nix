{ pkgs ? import <nixpkgs> {} }:
with pkgs;
stdenv.mkDerivation {
  name = "personal-servers";
  buildInputs = [ nixops ];
  nativeBuildInputs = [  ];
}

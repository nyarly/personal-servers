{ pkgs ? import <nixpkgs> {} }:
let
  inherit (pkgs) lib stdenv ruby bundler bundlerEnv fetchFromGitHub;

  rubyEnv = bundlerEnv {
    inherit ruby;

    name = "jekyll-blog";

    gemfile = ./Gemfile;
    lockfile = ./Gemfile.lock;
    gemset = ./gemset.nix;
  };
in
  stdenv.mkDerivation {
    name = "jdl-blog";

    src = fetchFromGitHub {
      owner = "nyarly";
      repo = "blog";
      rev = "master";
      sha256 = "1rcim9scfxi1z2dsgznqgbqbnff628cxl96shnlpbbsi099prsdy";
    };

    buildInputs = [
      rubyEnv
      bundler
    ];

    buildPhase = "jekyll build";
    installPhase = "cp -a _site $out";
  }

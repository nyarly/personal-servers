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
    name = "blog-jdl";

    src = fetchFromGitHub (
      builtins.fromJSON
      (builtins.readFile ./source.json) // {
        owner = "nyarly";
        repo = "blog";
        } );

    buildInputs = [
      rubyEnv
    ];

    buildPhase = "jekyll build";
    installPhase = "cp -a _site $out";
  }

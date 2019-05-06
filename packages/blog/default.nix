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

    src = if builtins.pathExists(./source.json) then
    fetchFromGitHub (
      builtins.fromJSON (builtins.readFile ./source.json) //
      { private = true; owner = "nyarly"; repo = "blog"; }
    )
    else
      ./.;

    buildInputs = [
      rubyEnv
    ];

    buildPhase = "jekyll build";
    installPhase = "cp -a _site $out";
  }

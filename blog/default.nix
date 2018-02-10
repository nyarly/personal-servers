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

    src = if builtins.pathExists(./source.nix) then
      fetchFromGitHub {
        owner = "nyarly";
        repo = "blog";
        rev = "master";
        sha256 = import ./source.nix;
        }
    else
      ./.;

    buildInputs = [
      rubyEnv
      bundler
    ];

    buildPhase = "jekyll build";
    installPhase = "cp -a _site $out";
  }

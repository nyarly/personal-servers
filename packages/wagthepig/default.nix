{ stdenv, bundlerEnv, fetchFromGitHub, ruby, nodejs, ... }:

let
  package = "wagthepig";
  version = "2018-09-17";
  owner = "nyarly";
  repo = "wagthepig";

  env = bundlerEnv {
    name = "${package}-${version}-railsenv";
    inherit ruby;
    gemdir = ./.;
  };

  runDir = "/run/${package}";
in

stdenv.mkDerivation rec {
  name = "${package}-${version}";

  src = fetchFromGitHub (
    builtins.fromJSON
      (builtins.readFile ./source.json) //
      { inherit owner repo; }
  );

  buildInputs = [ env nodejs ];

  buildPhase = ''
    echo > config/database.yml
    ${env}/bin/rake assets:precompile RAILS_ENV=production
  '';

  # From frab
  # cp .env.development .env.production
  # rm .env.production

  installPhase = ''
    mkdir -p $out/share
    cp -r . $out/share/${package}

    ln -sf ${runDir}/database.yml $out/share/${package}/config/database.yml
    rm -rf $out/share/${package}/tmp $out/share/${package}/public/system
    ln -sf ${runDir}/system $out/share/${package}/public/system
    ln -sf /tmp $out/share/${package}/tmp
  '';

  passthru = {
    inherit env ruby runDir;
  };
}

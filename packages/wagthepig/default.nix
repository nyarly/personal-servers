{ stdenv, bundlerEnv, fetchFromGitHub, ruby  }:

let
  env = bundlerEnv {
    name = "wagthepig-railsenv";
    inherit ruby;
    gemdir = ./.;
  };

  name = "wagthepig";

  runDir = "/run/${name}";
in

stdenv.mkDerivation rec {
  package = name;
  version = "2018-09-17";

  src = fetchFromGitHub {
    owner = "nyarly";
    repo = "wagthepig";
  } // import ./source-id.nix;

  buildInputs = [ env ];

  buildPhase = ''
    cp config/database.yml.template config/database.yml
    bundler exec rake assets:precompile RAILS_ENV=production
  '';

  # From frab
  # cp .env.development .env.production
  # rm .env.production

  installPhase = ''
    mkdir -p $out/share
    cp -r . $out/share/${name}

    ln -sf ${runDir}/database.yml $out/share/${name}/config/database.yml
    rm -rf $out/share/${name}/tmp $out/share/${name}/public/system
    ln -sf ${runDir}/system $out/share/${name}/public/system
    ln -sf /tmp $out/share/${name}/tmp
  '';

  passthru = {
    inherit env ruby runDir;
  };
}

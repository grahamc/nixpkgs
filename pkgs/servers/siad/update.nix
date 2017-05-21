let
  pkgs = import ../../.. {};
  inherit (pkgs) stdenv go2nix go_1_8;
in stdenv.mkDerivation {
  name = "siad-update";
  buildInputs = [
    go2nix
    go_1_8
  ];

  shellHook = ''
    set -eux
    mkdir -p tmp
    cd tmp
    export GOPATH=`pwd`
    go get -u github.com/NebulousLabs/Sia/siad
    cd src/github.com/NebulousLabs/Sia/siad
    go2nix save
    mv *.nix ../../../../../
    set +eux
  '';
}

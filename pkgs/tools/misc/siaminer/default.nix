{ stdenv, fetchFromGitHub, opencl-headers, ocl-icd, curl }:
stdenv.mkDerivation rec {
  name = "sia-gpu-miner-${version}";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "NebulousLabs";
    repo = "Sia-GPU-Miner";
    rev = "v${version}";
    sha256 = "1iry56i16nipq6illbfadsahrsdvvmavbxblz4cdzd0y1fq98y51";
  };

  patches = [
    ./sia-gpu-miner-path.patch
  ];

  buildInputs = [
    ocl-icd
    opencl-headers
    curl
  ];

  postPatch = ''
    substituteAllInPlace ./sia-gpu-miner.c
  '';

  installPhase = ''
    mkdir result
    (
      cd result
      mkdir bin lib
      mv ../sia-gpu-miner bin/
      mv ../sia-gpu-miner.cl lib/sia-gpu-miner.cl
    )
    mv result $out
  '';
}

/* This file defines the builds that constitute the Nixpkgs.
   Everything defined here ends up in the Nixpkgs channel.  Individual
   jobs can be tested by running:

   $ nix-build pkgs/top-level/release.nix -A <jobname>.<system>

   e.g.

   $ nix-build pkgs/top-level/release.nix -A coreutils.x86_64-linux
*/
{ nixpkgs ? { outPath = (import ../../lib).cleanSource ../..; revCount = 1234; shortRev = "abcdef"; revision = "0000000000000000000000000000000000000000"; }
, officialRelease ? false
  # The platforms for which we build Nixpkgs.
, supportedSystems ? [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" ]
, limitedSupportedSystems ? [ "i686-linux" ]
  # Strip most of attributes when evaluating to spare memory usage
, scrubJobs ? true
  # Attributes passed to nixpkgs. Don't build packages marked as unfree.
, nixpkgsArgs ? { config = { allowUnfree = false; inHydra = true; }; }
}:

with import ./release-lib.nix { inherit supportedSystems scrubJobs nixpkgsArgs; };

let

  systemsWithAnySupport = supportedSystems ++ limitedSupportedSystems;

  supportDarwin = builtins.elem "x86_64-darwin" systemsWithAnySupport;

  jobs = {
    inherit (pkgs) hello;
  };
in jobs

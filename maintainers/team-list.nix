/* List of maintainer teams.
    name = {
      # Required
      members = [ maintainer1 maintainer2 ];
      scope = "Maintain foo packages.";
    };

  where

  - `members` is the list of maintainers belonging to the group,
  - `scope` describes the scope of the group.

  More fields may be added in the future.

  When editing this file:
   * keep the list alphabetically sorted
   * test the validity of the format with:
       nix-build lib/tests/teams.nix
  */

{ lib }:
with lib.maintainers; {
  freedesktop = {
    members = [ jtojnar worldofpeace ];
    scope = "Maintain Freedesktop.org packages for graphical desktop.";
  };

  gnome = {
    members = [
      hedning
      jtojnar
      worldofpeace
    ];
    scope = "Maintain GNOME desktop environment and platform.";
  };

  podman = {
    members = [
      saschagrunert
      vdemeester
      zowoq
    ];
    scope = "Maintain podman related packages.";
  };
}

# The boot console for a host with a virtual terminal to draw on.
#
# bootvine replaces the scrolling kernel and systemd lines with a live tree of
# the jobs still pending, a timeline of the slowest ones that ran, the last
# journal lines of a failed unit, and an in-place prompt for a passphrase such
# as a LUKS unlock. With a systemd initrd it starts there and survives the
# switch to the real root, so the initrd and stage 2 are one tree; it hands
# the console back when the default target is reached and returns for the
# shutdown.
#
# Import it where the console is a VT. The Chromebook does not: the Baguette
# VM's console is crosvm's serial one, so bootvine would draw on nothing and
# fail as a unit.
#
# Guide: https://codeberg.org/wvhulle/bootvine/src/branch/main/docs/guide.md
{inputs, ...}: {
  imports = [inputs.bootvine.nixosModules.default];

  services.bootvine.enable = true;
}

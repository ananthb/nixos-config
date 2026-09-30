{
  stdenvNoCC,
  fetchFromGitHub,
  qmk,
  dfu-util,
  writeShellApplication,
}: let
  # Oryx builds against ZSA's fork; the branch matches Oryx's "firmware vNN" badge.
  firmware = stdenvNoCC.mkDerivation {
    pname = "moonlander-firmware";
    version = "25-unstable-2026-09-02";

    src = fetchFromGitHub {
      owner = "zsa";
      repo = "qmk_firmware";
      rev = "93b2b9ec3368f86c5eb5a2e3f934049f8daef885";
      fetchSubmodules = true;
      hash = "sha256-jWMYpBx7NT2953sWkB2KEetnlGPthtkdYYzW3/dtVZY=";
    };

    nativeBuildInputs = [qmk];

    postPatch = ''
      cp -r ${./keymap} keyboards/zsa/moonlander/keymaps/ananth
    '';

    buildPhase = ''
      runHook preBuild
      export HOME=$TMPDIR QMK_HOME=$PWD
      # USER_NAME defaults to the keymap, and QMK globs /users/ananth, which macOS resolves to /Users/ananth.
      make -j$NIX_BUILD_CORES SKIP_GIT=yes USER_NAME=nix-build \
        zsa/moonlander/reva:ananth zsa/moonlander/revb:ananth
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm444 zsa_moonlander_reva_ananth.bin $out/reva.bin
      install -Dm444 zsa_moonlander_revb_ananth.bin $out/revb.bin
      runHook postInstall
    '';
  };
in {
  inherit firmware;

  # Rev A sits in ST's ROM bootloader, rev B in ZSA's; the USB ID says which.
  flash = writeShellApplication {
    name = "flash-moonlander";
    runtimeInputs = [dfu-util];
    text = ''
      echo "Press the Moonlander's reset button."
      until devices=$(dfu-util -l 2>/dev/null) && grep -qiE '0483:df11|3297:2003' <<<"$devices"; do
        sleep 0.5
      done
      if grep -qi '3297:2003' <<<"$devices"; then
        dfu-util -d 3297:2003 -a 0 -s 0x08002000:leave -D ${firmware}/revb.bin
      else
        dfu-util -d 0483:df11 -a 0 -s 0x08000000:leave -D ${firmware}/reva.bin
      fi
    '';
  };
}

{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "spotify-tray-wayland";
  version = "unstable";

  src = fetchFromGitHub {
    owner = "xander1421";
    repo = "spotify-tray-wayland";
    rev = "main";
    hash = "sha256-rD/5OfJSnHv6aSuC4kbSG82zizxEAr3tSkeFx3L55gs=";
  };

  sourceRoot = "source/spotify-tray-wayland";

  vendorHash = "sha256-2o+mtkOS+69kB9SyTIotTxr0b9UVhkefHfw7vPHIbr0=";

  meta = {
    description = "Native Wayland system tray icon for Spotify with Hyprland integration";
    homepage = "https://github.com/xander1421/spotify-tray-wayland";
    license = lib.licenses.gpl3Only;
    mainProgram = "spotify-tray-wayland";
    platforms = lib.platforms.linux;
  };
}

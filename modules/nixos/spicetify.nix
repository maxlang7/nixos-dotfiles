{pkgs, inputs, ... }:

{
  imports = [
    inputs.spicetify-nix.nixosModules.spicetify
  ];
  programs.spicetify =
  let
    spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  in
  {
    enable = true;
    windowManagerPatch = true;
    wayland = true;
    spotifywmPackage = pkgs.spotifywm;
    enabledExtensions = with spicePkgs.extensions; [
      adblock
      hidePodcasts
      shuffle # shuffle+ (special characters are sanitized out of extension names)
      wikify
      songStats
      showQueueDuration
      keyboardShortcut
      history
      bookmark
      playNext
    ];
    enabledCustomApps = [
      #spicePkgs.apps.reddit
      # spicePkgs.apps.ncsVisualizer
      ({
          src = pkgs.fetchFromGitHub {
            owner = "grademach";
            repo = "spotify-downloader";
            rev = "main"; # You can use a specific commit hash for stability
            hash = "sha256-PEJgTmADx1kfT3FqguAMlwOIcEgzeovPhz/GtfKnXLk=";
          };
          # The actual file name of the customApp usually ends with .js
          name = "song-downloader.js";
      })
    ];
    # enabledSnippets = with spicePkgs.snippets; [
    #   # rotatingCoverart
    #   #pointer
    # ];
  
    theme = spicePkgs.themes.text;
    colorScheme = "Gruvbox";
  };
}
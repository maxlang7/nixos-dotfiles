# ════════════════════════════════════════════════════════════════════════════
#  sops-nix — central secret declarations
# ────────────────────────────────────────────────────────────────────────────
#  TO DISABLE ALL SECRETS:  comment out `./sops.nix` in maxlang.nix, AND comment
#  the clearly-marked "sops" blocks in navidrome.nix / wireguard.nix.
#
#  Edit secrets:   cd artifacts/sops && nix-shell -p age sops --run \
#                  'SOPS_AGE_KEY_FILE=age/keys.txt sops secrets/secrets.yaml'
#  Add a recipient: put its age public key in artifacts/sops/.sops.yaml, then
#                  `sops updatekeys secrets/secrets.yaml`.
#
#  The age PRIVATE key lives at artifacts/sops/age/keys.txt and is .gitignored.
#  Only .sops.yaml (public recipients) + the encrypted secrets.yaml are committed.
# ════════════════════════════════════════════════════════════════════════════
{ inputs, config, user, ... }:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops.defaultSopsFile = ../../artifacts/sops/secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";

  # NOTE: absolute path on purpose — sops-nix activates from "/", so a relative
  # path here would silently fail to find the key.
  sops.age.keyFile = "/etc/nixos/artifacts/sops/age/keys.txt";

  # ── individual secrets ────────────────────────────────────────────────────
  # Each `config.sops.secrets.<name>.path` is a runtime file (default /run/secrets/<name>),
  # decrypted at activation. Comment any line to stop provisioning that secret.
  sops.secrets.cmu-pass.owner = config.users.users.${user}.name;

  # Canvas LMS personal access token (canvas.cmu.edu) — read by the local
  # canvas tool that runs as ${user}.
  sops.secrets."canvas-token".owner = config.users.users.${user}.name;

  sops.secrets."navidrome-lastfm-apikey" = { };
  sops.secrets."navidrome-lastfm-secret" = { };

  sops.secrets."wireguard-private-key" = { };
  sops.secrets."wireguard-preshared-key" = { };

  # BlueBubbles server password — consumed as an EnvironmentFile by
  # imessage-bridge.nix (BB_PASSWORD).
  sops.secrets."bluebubbles-password" = { };

  # ── rendered env file for navidrome (combines two secrets into one file) ───
  # Used as systemd EnvironmentFile in navidrome.nix.
  sops.templates."navidrome.env".content = ''
    ND_LASTFM_APIKEY=${config.sops.placeholder."navidrome-lastfm-apikey"}
    ND_LASTFM_SECRET=${config.sops.placeholder."navidrome-lastfm-secret"}
  '';

  # ── rendered env file for the iMessage bridge (imessage-bridge.nix) ────────
  sops.templates."imessage-bridge.env".content = ''
    BB_PASSWORD=${config.sops.placeholder."bluebubbles-password"}
  '';
}

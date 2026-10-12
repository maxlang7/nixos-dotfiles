{ user, ... }:
{
  sops.secrets."blueferry-beeper-config" = {
    sopsFile = ../../artifacts/sops/secrets/blueferry-beeper.yaml;
    format = "yaml";
    key = "";
    owner = user;
    group = "users";
    mode = "0400";
  };
}

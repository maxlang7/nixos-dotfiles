{ ... }: {
  # Connect headphone control for battery reports while keeping playback stereo.
  xdg.configFile."wireplumber/wireplumber.conf.d/zz-headphone-stereo.conf" = {
    force = true;
    text = ''
      monitor.bluez.rules = [
        {
          matches = [ { device.name = "bluez_card.7C_FE_62_4B_24_10" } ]
          actions = {
            update-props = {
              bluez5.auto-connect = [ a2dp_source hfp_ag ]
            }
          }
        }
      ]
      wireplumber.settings = {
        bluetooth.autoswitch-to-headset-profile = false
      }
    '';
  };
}

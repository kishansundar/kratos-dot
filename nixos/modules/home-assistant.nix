# Home Assistant: the Ecovacs Deebot N8 (through Ecovacs' cloud), passed to Apple Home by Matterbridge (matterbridge.nix).
{
  services.home-assistant = {
    enable = true;
    # Ecovacs for the vacuum, HomeKit Bridge for the preset buttons; the rest are what first-run setup expects.
    extraComponents = [
      "ecovacs"
      "homekit"
      "analytics"
      "google_translate"
      "met"
      "radio_browser"
      "shopping_list"
      "isal"
    ];
    config = {
      default_config = { };
      homeassistant = {
        name = "Kratos";
        time_zone = "Asia/Kolkata";
        unit_system = "metric";
        country = "IN";
      };
      # The cleaning presets reach Apple Home as switches through a HomeKit bridge of their own (so Siri can run them by
      # name). Matterbridge gives scripts a Matter device type Apple Home doesn't show; the vacuum itself stays on Matter.
      homekit = [
        {
          name = "Deebot Buttons";
          port = 21064;
          advertise_ip = "10.0.0.48"; # Kratos's fixed lease in the Pi-hole
          filter.include_entities = [
            "script.deebot_quiet_clean"
            "script.deebot_normal_clean"
            "script.deebot_deep_clean"
            "script.deebot_locate"
          ];
        }
      ];
      # Cleaning presets.
      # A preset's suction stays set afterwards: Apple Home's own Start then uses it too.
      script =
        let
          deebot.entity_id = "vacuum.deebot_n8";
          cleanAt = alias: speed: {
            inherit alias;
            icon = "mdi:robot-vacuum";
            sequence = [
              { action = "vacuum.set_fan_speed"; target = deebot; data.fan_speed = speed; }
              { action = "vacuum.start"; target = deebot; }
            ];
          };
        in
        {
          deebot_quiet_clean = cleanAt "Quiet clean" "quiet";
          deebot_normal_clean = cleanAt "Normal clean" "normal";
          deebot_deep_clean = cleanAt "Deep clean" "max_plus";
          deebot_locate = {
            alias = "Locate Deebot";
            icon = "mdi:map-marker-radius";
            sequence = [ { action = "vacuum.locate"; target = deebot; } ];
          };
        };
    };
  };
  # HomeKit on the home network: the bridge's port (mDNS, UDP 5353, is already open for Scrypted).
  networking.firewall.allowedTCPPorts = [ 21064 ];
  # Home Assistant's own page over Tailscale only, like Scrypted's; on Kratos itself it is http://localhost:8123.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8123 ];
}

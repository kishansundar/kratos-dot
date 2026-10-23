# Matterbridge: the Deebot N8 (through Home Assistant) in Apple Home as a Matter robot vacuum instead of a switch.
{
  virtualisation.oci-containers.containers.matterbridge = {
    image = "docker.io/luligu/matterbridge:latest"; # Podman needs the full registry name
    # Checks for a newer image at each start; keeps the old one if the internet is down.
    pull = "newer";
    # Matter and its discovery (mDNS) need Kratos's own network, like Scrypted's HomeKit.
    extraOptions = [ "--network=host" "--stop-timeout=60" ];
    volumes = [
      "/var/lib/matterbridge/plugins:/root/Matterbridge"
      "/var/lib/matterbridge/storage:/root/.matterbridge"
      "/var/lib/matterbridge/cert:/root/.mattercert"
    ];
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/matterbridge 0700 root root -"
    "d /var/lib/matterbridge/plugins 0700 root root -"
    "d /var/lib/matterbridge/storage 0700 root root -"
    "d /var/lib/matterbridge/cert 0700 root root -"
  ];
  # Matter on the home network: 5540 for the bridge, the next ports for devices in server mode (the vacuum).
  networking.firewall.allowedUDPPortRanges = [ { from = 5540; to = 5559; } ];
  # Matterbridge's settings page over Tailscale only, like Scrypted's; on Kratos itself it is http://localhost:8283.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8283 ];
}

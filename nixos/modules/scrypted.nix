# Scrypted: the six XVR cameras in Apple's Home app (live view and motion alerts, no recording).
{
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.containers.scrypted = {
    image = "ghcr.io/koush/scrypted:latest";
    # Checks for a newer image at each start; keeps the old one if the internet is down.
    pull = "newer";
    # HomeKit needs Kratos's own network (Scrypted's official setup).
    extraOptions = [ "--network=host" ];
    volumes = [ "/var/lib/scrypted:/server/volume" ];
  };
  systemd.tmpfiles.rules = [ "d /var/lib/scrypted 0700 root root -" ];
  # HomeKit on the home network: discovery (mDNS) and the fixed ports set in Scrypted (bridge 41000, cameras 41001-41006).
  networking.firewall.allowedUDPPorts = [ 5353 ];
  networking.firewall.allowedTCPPortRanges = [ { from = 41000; to = 41010; } ];
  # Live video replies (RTCP) from iPhones and the Apple TV use random UDP ports: accept UDP from the home network only.
  networking.firewall.extraCommands = "iptables -A nixos-fw -s 10.0.0.0/24 -p udp -j nixos-fw-accept";
  # Scrypted's admin page over Tailscale only.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 10443 ];
}

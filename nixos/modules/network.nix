# How this machine is reached: Wi-Fi through NetworkManager, the tailnet (Tailscale), and SSH over the tailnet or the LAN.
# The Wi-Fi driver's own settings are in hardware.nix.
{
  # Wi-Fi and Ethernet. Use nmtui or nmcli to connect.
  networking.networkmanager.enable = true;
  # No ModemManager, which NetworkManager brings for mobile-broadband modems: there is none (audit D11).
  networking.modemmanager.enable = false;
  # No Wi-Fi power saving: the RTL8822BE (rtw88) lost the access point's beacons about 150 times an hour with it on, and
  # Wi-Fi is this machine's only link for SSH, Tailscale and RustDesk (audit NET-01). The driver side is in hardware.nix.
  networking.networkmanager.wifi.powersave = false;
  services.tailscale.enable = true;
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ]; # SSH (services.openssh below)
  # LAN SSH from any house device (no fixed leases needed), never from the router .1 or the Pi's subnet-route address .2; IPv4 only.
  networking.firewall.extraCommands = "iptables -A nixos-fw ! -i tailscale0 -p tcp --dport 22 -m iprange --src-range 10.0.0.3-10.0.0.254 -j nixos-fw-accept";
  # Applied at boot with `tailscale set`: Tailscale DNS stays off (your own DNS keeps answering), and kishan may run
  # `tailscale up` / `down` / `set` without sudo (the shell's dashboard switch uses it).
  services.tailscale.extraSetFlags = [ "--accept-dns=false" "--operator=kishan" ];

  # Key login only (audit SEC-01); port 22 over Tailscale and, since 24 Oct 2026, the LAN (K-1, K-2); RustDesk and the console remain if the keys are lost.
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PermitRootLogin = "no";
  };
  users.users.kishan.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAj6VIwrM1ZSOuOj3NOsd4WQIkhrxqEKiV11z8b30Jle kishan@nixos"
    # MacBook Pro (kishans-macbook-pro on Tailscale), sent by Taildrop 19 Oct 2026; fingerprint checked on the Mac.
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKJNDKV64BO4Un63r8Tnn56o+bCm1TrEfsHJ9QKgI59K kishans-macbook-pro"
  ];
}

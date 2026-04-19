{ pkgs, vars, ... }:

{
  networking.hostName = vars.hostname;

  networking.networkmanager = {
    enable = true;
    plugins = [ pkgs.networkmanager-openvpn ];
  };

  services.resolved.enable = true;

  # Tailscale VPN
  services.tailscale.enable = true;

  # Симлинк для update-systemd-resolved (стабильный путь для OpenVPN)
  environment.etc."openvpn/update-systemd-resolved" = {
    source = "${pkgs.openvpn}/libexec/update-systemd-resolved";
    mode = "0755";
  };
}

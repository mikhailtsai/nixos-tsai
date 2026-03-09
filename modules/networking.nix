{ pkgs, vars, ... }:

{
  networking.hostName = vars.hostname;

  # Корпоративные тестовые домены Skyeng
  networking.extraHosts = ''
    127.0.0.1 teacher.test-y161.skyeng.link
    127.0.0.1 teachers.test-y161.skyeng.link
    127.0.0.1 acv.test-y161.skyeng.link
    127.0.0.1 onboarding.test-y161.skyeng.link
    127.0.0.1 trm.test-y161.skyeng.link
    ::1 teacher.test-y161.skyeng.link
    ::1 teachers.test-y161.skyeng.link
    ::1 acv.test-y161.skyeng.link
    ::1 onboarding.test-y161.skyeng.link
    ::1 trm.test-y161.skyeng.link
    127.0.0.1 teacher.test-y159.skyeng.link
    127.0.0.1 teachers.test-y159.skyeng.link
    127.0.0.1 acv.test-y159.skyeng.link
    127.0.0.1 onboarding.test-y159.skyeng.link
    127.0.0.1 trm.test-y159.skyeng.link
    ::1 teacher.test-y159.skyeng.link
    ::1 teachers.test-y159.skyeng.link
    ::1 acv.test-y159.skyeng.link
    ::1 onboarding.test-y159.skyeng.link
    ::1 trm.test-y159.skyeng.link
  '';

  networking.networkmanager = {
    enable = true;
    plugins = [ pkgs.networkmanager-openvpn ];
  };

  services.resolved.enable = true;

  # Симлинк для update-systemd-resolved (стабильный путь для OpenVPN)
  environment.etc."openvpn/update-systemd-resolved" = {
    source = "${pkgs.openvpn}/libexec/update-systemd-resolved";
    mode = "0755";
  };
}

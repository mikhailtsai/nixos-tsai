{ pkgs, ... }:

# Личные хранилища:
#   ~/Storage — открытый раздел (p5, ext4), монтируется при загрузке
#   ~/Vault   — зашифрованный раздел (p3, LUKS), монтируется по требованию
#               командой `vault` и блокируется сразу после выхода из yazi.

let
  vaultDev  = "/dev/disk/by-partuuid/45804b7e-9268-4104-bc42-0aeac50b9d50";
  vaultName = "vault";
  vaultMnt  = "/home/leet/Vault";

  # Привилегированная часть: открыть LUKS + смонтировать.
  # cryptsetup сам спросит passphrase в терминале — это и есть защита.
  vault-mount = pkgs.writeShellScriptBin "vault-mount" ''
    set -e
    if [ ! -e /dev/mapper/${vaultName} ]; then
      ${pkgs.cryptsetup}/bin/cryptsetup luksOpen ${vaultDev} ${vaultName}
    fi
    ${pkgs.coreutils}/bin/mkdir -p ${vaultMnt}
    ${pkgs.util-linux}/bin/mount /dev/mapper/${vaultName} ${vaultMnt}
    ${pkgs.coreutils}/bin/chown leet:users ${vaultMnt}
  '';

  # Привилегированная часть: размонтировать + закрыть LUKS.
  vault-umount = pkgs.writeShellScriptBin "vault-umount" ''
    ${pkgs.coreutils}/bin/sync || true
    if ${pkgs.util-linux}/bin/mountpoint -q ${vaultMnt}; then
      # Не размонтируем силой: если Vault занят другим процессом, ленивый umount
      # оставит раздел расшифрованным «невидимо». Честно откажемся и покажем, кто держит.
      if ! ${pkgs.util-linux}/bin/umount ${vaultMnt} 2>/dev/null; then
        echo "⚠️  Vault занят другим процессом — оставляю смонтированным (иначе можно потерять данные)." >&2
        echo "    Держат Vault:" >&2
        ${pkgs.psmisc}/bin/fuser -vm ${vaultMnt} >&2 2>&1 || true
        echo "    Закрой их и выполни: sudo vault-umount" >&2
        exit 1
      fi
    fi
    if [ -e /dev/mapper/${vaultName} ]; then
      ${pkgs.cryptsetup}/bin/cryptsetup luksClose ${vaultName}
    fi
  '';
in
{
  environment.systemPackages = [ pkgs.cryptsetup vault-mount vault-umount ];

  # Открытое хранилище (p5) — монтируется при загрузке, без пароля.
  fileSystems."/home/leet/Storage" = {
    device  = "/dev/disk/by-uuid/aa6bd3c9-3a1b-4f8f-9047-aa6ea8d7e71d";
    fsType  = "ext4";
    options = [ "defaults" "nofail" "x-gvfs-show" ];
  };

  # leet может открывать/закрывать Vault без пароля sudo.
  # Единственный барьер — LUKS-passphrase, cryptsetup спрашивает её каждый раз.
  security.sudo.extraRules = [{
    users = [ "leet" ];
    commands = [
      { command = "/run/current-system/sw/bin/vault-mount";   options = [ "SETENV" "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/vault-umount"; options = [ "SETENV" "NOPASSWD" ]; }
    ];
  }];
}

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
      # 1) Мягко: несколько попыток — даём yazi и его хелперам (превью и т.п.)
      #    самим освободить точку монтирования, чтобы никого не убивать зря.
      for _ in 1 2 3 4 5; do
        ${pkgs.util-linux}/bin/umount ${vaultMnt} 2>/dev/null && break
        ${pkgs.coreutils}/bin/sleep 0.3
      done
      # 2) Всё ещё занято (напр. окно закрыли через super+q, хелперы зависли) —
      #    форсим: показываем и принудительно завершаем держащих, затем umount.
      if ${pkgs.util-linux}/bin/mountpoint -q ${vaultMnt}; then
        echo "⚠️  Vault занят — принудительно завершаю держащие процессы:" >&2
        ${pkgs.psmisc}/bin/fuser -vm ${vaultMnt} >&2 2>&1 || true
        ${pkgs.psmisc}/bin/fuser -km ${vaultMnt} 2>/dev/null || true
        ${pkgs.coreutils}/bin/sleep 0.5
        ${pkgs.util-linux}/bin/umount ${vaultMnt} 2>/dev/null \
          || ${pkgs.util-linux}/bin/umount -l ${vaultMnt}
      fi
    fi
    # luksClose с ретраем: устройство может ещё пару мгновений быть занятым.
    if [ -e /dev/mapper/${vaultName} ]; then
      for _ in 1 2 3 4 5; do
        ${pkgs.cryptsetup}/bin/cryptsetup luksClose ${vaultName} && break
        ${pkgs.coreutils}/bin/sleep 0.3
      done
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

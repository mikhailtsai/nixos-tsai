Build OS:

```shell
sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
git add .
sudo nixos-rebuild switch --flake ./#nixos
```

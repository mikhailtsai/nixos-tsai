{ pkgs, vars, ... }:

let
  modelsDir = "/home/${vars.username}/Models/ComfyUI";

  extraModelPaths = pkgs.writeText "comfyui-extra-model-paths.yaml" ''
    local_models:
      base_path: ${modelsDir}

      checkpoints: checkpoints/
      diffusion_models: diffusion_models/
      text_encoders: text_encoders/
      vae: vae/
  '';
in
{
  services.comfyui = {
    enable = true;

    # NVIDIA RTX 4080 Laptop
    gpuSupport = "cuda";

    # Web UI
    listenAddress = "127.0.0.1";
    port = 8188;
    openFirewall = false;

    user = vars.username;
    group = "users";
    createUser = false;

    dataDir = "/home/${vars.username}/.local/share/comfyui";

    enableManager = true;

    extraArgs = [
      "--extra-model-paths-config"
      "${extraModelPaths}"
    ];
  };
}

{ config, pkgs, vars, ... }:

let
  modelsDir = "/home/${vars.username}/Storage/Models/ComfyUI";

  extraModelPaths = pkgs.writeText "comfyui-extra-model-paths.yaml" ''
    local_models:
      base_path: ${modelsDir}

      checkpoints: checkpoints/
      diffusion_models: diffusion_models/
      text_encoders: text_encoders/
      vae: vae/
      loras: loras/
  '';

  # Форк city96/ComfyUI-GGUF от leejet (автор stable-diffusion.cpp):
  # upstream + поддержка архитектуры qwen_image21 (Qwen-Image 2.1 GGUF).
  # Убрать, когда comfyui-nix/city96 догонят.
  ggufLeejet = pkgs.fetchFromGitHub {
    owner = "leejet";
    repo = "ComfyUI-GGUF";
    rev = "373048b8403a7820620065210a691263d4da0a61";
    hash = "sha256-Zbb833PFruwYbmYIeRHH0mLf8jBCn/13J4dRyBK4yIs=";
  };

  # comfyui-nix линкует встроенный ComfyUI-GGUF из лаунчера и перетирает
  # одноимённые customNodes — поэтому подменяем путь прямо в лаунчере.
  comfyBase = config.services.comfyui.packageSet.cuda;
  comfyPatched = pkgs.runCommand "comfy-ui-gguf-leejet" { } ''
    mkdir -p $out/bin
    sed -E 's|/nix/store/[a-z0-9]{32}-comfyui-gguf-[^"]*|${ggufLeejet}|g' \
      ${comfyBase}/bin/comfy-ui > $out/bin/comfy-ui
    grep -q '${ggufLeejet}' $out/bin/comfy-ui
    chmod +x $out/bin/comfy-ui
    ln -s comfy-ui $out/bin/comfyui
  '';

  # Ноды Viggle Turbo для Qwen-Image 2.1: 6-шаговое расписание sigma
  # и LoRA без слияния в веса (y = Wx + BAx). Файл запинен на коммит HF.
  viggleTurbo = pkgs.runCommand "comfyui-viggle-turbo" {
    src = pkgs.fetchurl {
      url = "https://huggingface.co/Viggle/Qwen-Image-2.1-viggle-turbo/resolve/bb26a0f38e5fe6c124aaccc9187a87eed5d9ed13/comfyui/viggle_turbo.py";
      hash = "sha256-AXkRu32chVxupoVK3u7qGu1XbKHJy0hzdkGfW64U6T0=";
    };
  } ''
    mkdir -p $out
    cp $src $out/__init__.py
  '';
in
{
  services.comfyui = {
    enable = true;

    # NVIDIA RTX 4080 Laptop
    gpuSupport = "cuda";
    package = comfyPatched;

    # Web UI
    listenAddress = "127.0.0.1";
    port = 8188;
    openFirewall = false;

    user = vars.username;
    group = "users";
    createUser = false;

    dataDir = "/home/${vars.username}/.local/share/comfyui";

    enableManager = true;

    customNodes.viggle-turbo = viggleTurbo;

    extraArgs = [
      "--extra-model-paths-config"
      "${extraModelPaths}"
    ];
  };
}

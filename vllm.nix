{
  config,
  pkgs,
  pkgs-vllm, # note: set in flake.nix to "github:CertainLach/nixpkgs/push-lklxouywkrnv";
  ...
}:
let
  pythonPackages = pkgs-vllm.python3Packages;

  torch = pythonPackages.torchWithCuda;
  torchvision = pythonPackages.torchvision.override {
    inherit torch;
  };
  torchaudio = pythonPackages.torchaudio.override {
    inherit torch;
  };
  xformers = pythonPackages.xformers.override {
    inherit torch;
  };

  mistral-common = pythonPackages.mistral-common.overridePythonAttrs (old: {
    version = "1.11.0";
    src = pkgs-vllm.fetchFromGitHub {
      owner = "mistralai";
      repo = "mistral-common";
      tag = "v1.11.0";
      hash = "sha256-DejbLY2i6Hp1J+spxMut5RKugj7rDyrZmp6v+5wqyWY=";
    };
    doCheck = false;
  });
  vllm = pythonPackages.vllm.override {
    inherit torch torchvision torchaudio xformers;
  };
  vllmPatched = vllm.overridePythonAttrs (old: {
    dontCheckRuntimeDeps = true;
    dependencies = builtins.map
      (dep: if dep.pname or "" == "mistral-common" then mistral-common else dep)
      (old.dependencies or []);
  });
  # vLLM's GGUF loader does not support the qwen35 GGUF architecture yet, so use
  # a Hugging Face safetensors quant instead. This repo is an INT4/AWQ-ish
  # safetensors distribution for Qwen3.6-27B; its config advertises
  # Qwen3_5ForConditionalGeneration plus a compressed-tensors 4-bit quantization
  # config that vLLM can load through the normal HF model path.
  modelRepo = "cyankiwi/Qwen3.6-27B-AWQ-INT4";
  modelDir = "/var/lib/vllm/models/cyankiwi--Qwen3.6-27B-AWQ-INT4";
  model = modelDir;
in
{
  # Install both the server and HF CLI. The service uses absolute paths, but
  # keeping `hf` on PATH makes manual model management less surprising.
  environment.systemPackages = [
    vllmPatched
    pythonPackages.huggingface-hub
  ];

  systemd.services.vllm.path = with pkgs; [
    bash
    util-linux
  ];

  # Declaratively cap both RTX 3090s before inference starts. NixOS has
  # NVIDIA power-management options, but not a first-class per-GPU power-limit
  # option, so keep this as a small systemd unit rooted in the configured NVIDIA
  # driver package. 250 W is a good efficiency point for 3090 inference and keeps
  # the two-card setup under the worst-case 600W. Hoping to help with the fact
  # that I have only a 850W power supply.
  systemd.services.nvidia-power-limit = {
    description = "Set NVIDIA GPU persistence mode and power limit";
    wantedBy = [ "multi-user.target" ];
    before = [ "vllm.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = builtins.concatStringsSep " " [
        "${pkgs.bash}/bin/bash -euc"
        "'for gpu in 0 1; do ${config.hardware.nvidia.package.bin}/bin/nvidia-smi -i \"$gpu\" -pm 1; ${config.hardware.nvidia.package.bin}/bin/nvidia-smi -i \"$gpu\" -pl 250; done'"
      ];
    };
  };

  # Manual model download helper. This is intentionally a separate oneshot
  # service instead of ExecStartPre on vllm.service: downloading tens of GB is an
  # operational step, not part of starting the inference server. Usage after
  # changing modelRepo/modelDir. Use --no-block so your shell/rebuild workflow
  # does not wait for the full download:
  #   sudo systemctl start --no-block vllm-model-download.service
  #   journalctl -u vllm-model-download.service -f
  #   sudo systemctl restart vllm.service
  # This unit intentionally has no wantedBy= and is not required by vllm.service,
  # so nixos-rebuild/reboot will not automatically start a multi-hour download.
  systemd.services.vllm-model-download = {
    description = "Download model files for vLLM";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # If a download is already running while we switch configs, do not let
    # nixos-rebuild stop/restart this oneshot and block on the long job.
    restartIfChanged = false;
    stopIfChanged = false;

    environment = {
      HF_HOME = "/var/lib/vllm/huggingface";
    };

    serviceConfig = {
      Type = "oneshot";
      ExecStart = builtins.concatStringsSep " " [
        "${pkgs.bash}/bin/bash -lc"
        "'${pkgs.coreutils}/bin/mkdir -p ${modelDir} && ${pythonPackages.huggingface-hub}/bin/hf download ${modelRepo} --local-dir ${modelDir}'"
      ];
      TimeoutStartSec = "6h";
      User = "vllm";
      Group = "vllm";
      StateDirectory = "vllm";
    };
  };

  systemd.services.vllm = {
    description = "vLLM inference server";
    after = [ "network-online.target" "nvidia-power-limit.service" ];
    wants = [ "network-online.target" "nvidia-power-limit.service" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      HF_HOME = "/var/lib/vllm/huggingface";
      # Make the intended two-card serving topology explicit for future readers
      # and for any CUDA libraries that inspect visible devices before vLLM's
      # tensor-parallel worker setup.
      CUDA_VISIBLE_DEVICES = "0,1";
      VLLM_CPU_KVCACHE_SPACE = "8";
      # PyTorch suggested this after a near-capacity CUDA allocation failure;
      # it can reduce fragmentation when vLLM profiles/loads large models.
      PYTORCH_ALLOC_CONF = "expandable_segments:True";
    };

    serviceConfig = {
      ExecStart = builtins.concatStringsSep " " [
            "${vllmPatched}/bin/vllm serve ${model}"
            # Expose a stable API model id instead of leaking the local
            # /var/lib/vllm path through /v1/models and client configs.
            "--served-model-name qwen3-coder"
            "--host 127.0.0.1"
            "--port 8000"
            # Shard the model across both 24 GiB RTX 3090s. The old one-card
            # setup had to spend almost the entire GPU on weights and left very
            # little context; tensor parallelism splits weights/KV heads across
            # both cards and is the vLLM-native way to use the new second GPU.
            "--tensor-parallel-size 2"
            # 0.90 left only 0.14 GiB for KV cache on one 3090 after loading this
            # 27B model. With two cards, keep a little driver/runtime headroom
            # but use most VRAM for the longer coding context target.
            "--gpu-memory-utilization 0.95"
            "--enable-prefix-caching"
            "--enable-chunked-prefill"
            # Two cards should leave substantially more room for context than the
            # previous 23K single-card ceiling. Keep concurrency low for a
            # personal coding endpoint and cap chunked prefill memory per
            # scheduling step while allowing a 64K total request context.
            "--max-num-batched-tokens 8192"
            "--max-num-seqs 2"
            "--max-model-len 256K"
            "--async-scheduling"
            "--reasoning-parser qwen3"
            "--default-chat-template-kwargs '{\"enable_thinking\": true}'"
            "--enable-auto-tool-choice"
            "--tool-call-parser qwen3_coder"
	    "--language-model-only" # we don't need vision, we only want coding
	    "--speculative-config '{\"method\": \"mtp\", \"num_speculative_tokens\": 2}'"
          ];
      Restart = "on-failure";
      RestartSec = 10;
      User = "vllm";
      Group = "vllm";
      StateDirectory = "vllm";
    };
  };

  users.users.vllm = {
    isSystemUser = true;
    group = "vllm";
    home = "/var/lib/vllm";
    extraGroups = [ "video" "render" ];
  };
  users.groups.vllm = {};
}

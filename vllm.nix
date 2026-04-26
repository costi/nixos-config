{
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
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      HF_HOME = "/var/lib/vllm/huggingface";
      VLLM_CPU_KVCACHE_SPACE = "8";
      # PyTorch suggested this after a near-capacity CUDA allocation failure;
      # it can reduce fragmentation when vLLM profiles/loads large models.
      PYTORCH_ALLOC_CONF = "expandable_segments:True";
    };

    serviceConfig = {
      ExecStart = builtins.concatStringsSep " " [
            "${vllmPatched}/bin/vllm serve ${model}"
            "--host 127.0.0.1"
            "--port 8000"
            # 0.90 left only 0.14 GiB for KV cache after loading this 27B model.
            # At 0.95, vLLM should fit ~13k context; use 0.97 so two-request
            # serving can target a 16k coding context. If this conflicts with X
            # display/other CUDA processes, lower max_model_len before lowering
            # reliability-critical system services.
            "--gpu-memory-utilization 0.98"
            "--enable-prefix-caching"
            "--enable-chunked-prefill"
            # The 27B INT4/AWQ model nearly fills the RTX 3090 during vLLM's
            # startup profiling. The previous 32k/16seq/32k-batched settings
            # OOMed while flash-attention tried to allocate another ~288 MiB.
            # Keep the first working target conservative; raise these only after
            # confirming actual free VRAM in `journalctl -u vllm` / `nvidia-smi`.
            # Keep concurrency very low on the 24GB RTX 3090. Extra concurrent
            # requests need more scheduler/KV headroom; for this personal coding
            # endpoint, two simultaneous sequences is enough and saves VRAM.
            # Keep max_num_batched_tokens at 8192 so chunked prefill caps a
            # single scheduling step's memory use, while max_model_len allows a
            # longer 16k total request context for coding tasks.
            "--max-num-batched-tokens 8192"
            "--max-num-seqs 2"
            "--max-model-len 23K"
            "--async-scheduling"
            "--reasoning-parser qwen3"
            "--default-chat-template-kwargs '{\"enable_thinking\": true}'"
            "--enable-auto-tool-choice"
            "--tool-call-parser hermes"
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

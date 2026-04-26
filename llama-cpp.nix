{
  pkgs,
  pkgs-unstable,
  ...
}:
let
  # Use a recent llama.cpp from nixpkgs-unstable. Qwen3.6 GGUF/MoE support and
  # the newer cache/offload flags are moving quickly, and this avoids keeping
  # the old vLLM-specific nixpkgs fork in the serving path.
  llamaCpp = pkgs-unstable.llama-cpp.override {
    cudaSupport = true;
  };

  hf = pkgs.python3Packages.huggingface-hub;

  # Discussion that motivated this setup:
  # https://huggingface.co/Qwen/Qwen3.6-35B-A3B/discussions/37
  # The original RTX 3090 report used Unsloth's UD-Q3_K_M GGUF with llama.cpp.
  # It is small enough to fit on a 24GB card with a large KV cache, while still
  # leaving us room to experiment with long agentic/coding contexts.
  modelRepo = "unsloth/Qwen3.6-35B-A3B-GGUF";
  ggufFile = "Qwen3.6-35B-A3B-UD-Q3_K_M.gguf";
  modelDir = "/var/lib/llama-cpp/models/unsloth--Qwen3.6-35B-A3B-GGUF";
  modelPath = "${modelDir}/${ggufFile}";
in
{
  environment.systemPackages = [
    llamaCpp
    hf
  ];

  # Manual model download helper. This is intentionally separate from
  # llama-cpp.service: downloading a ~16 GiB model is an operational step, not
  # part of every server start/restart. Usage after rebuild:
  #   sudo systemctl start --no-block llama-cpp-model-download.service
  #   journalctl -u llama-cpp-model-download.service -f
  #   sudo systemctl restart llama-cpp.service
  systemd.services.llama-cpp-model-download = {
    description = "Download Qwen3.6 GGUF model for llama.cpp";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    restartIfChanged = false;
    stopIfChanged = false;

    environment = {
      HF_HOME = "/var/lib/llama-cpp/huggingface";
    };

    serviceConfig = {
      Type = "oneshot";
      ExecStart = builtins.concatStringsSep " " [
        "${pkgs.bash}/bin/bash -lc"
        "'${pkgs.coreutils}/bin/mkdir -p ${modelDir} && ${hf}/bin/hf download ${modelRepo} ${ggufFile} --local-dir ${modelDir}'"
      ];
      TimeoutStartSec = "6h";
      User = "llama-cpp";
      Group = "llama-cpp";
      StateDirectory = "llama-cpp";
    };
  };

  systemd.services.llama-cpp = {
    description = "llama.cpp OpenAI-compatible inference server";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      HF_HOME = "/var/lib/llama-cpp/huggingface";
    };

    serviceConfig = {
      ExecStart = builtins.concatStringsSep " " [
        "${llamaCpp}/bin/llama-server"
        "--model ${modelPath}"
        "--host 127.0.0.1"
        # Keep the previous vLLM endpoint port so local OpenAI-compatible
        # clients do not need reconfiguration during the runtime switch.
        "--port 8000"
        # The HF discussion reports 262k context on an RTX 3090. This is an
        # aggressive long-context target; reduce to 131072 or 65536 if startup
        # hits VRAM pressure or if interactive latency is worse than expected.
        "--ctx-size 262144"
        "--n-predict 32768"
        "--no-context-shift"
        "--flash-attn on"
        "--jinja"
        "--reasoning-format deepseek"
        "--reasoning-budget 4096"
        # A commenter in the same thread found preserving thinking helpful for
        # autonomous agentic tasks; keep it explicit so client behavior does not
        # silently change with future llama.cpp defaults.
        "--chat-template-kwargs '{\"preserve_thinking\":true}'"
        "--temp 0.6"
        "--top-p 0.95"
        "--top-k 20"
        "--min-p 0.00"
        "--presence-penalty 0.0"
        # The thread recommends q8_0 KV cache as a good memory/quality tradeoff
        # for long contexts. The original post used bf16; switch these back to
        # bf16 if q8_0 causes quality issues in practice.
        "--cache-type-k q8_0"
        "--cache-type-v q8_0"
        # For MoE GGUFs, recent llama.cpp can choose a better GPU/CPU placement
        # when n-gpu-layers is left unset. Reserve 2 GiB VRAM for the compositor,
        # other CUDA users, and transient allocations on the 24GB RTX 3090.
        "--fit-target 2048"
      ];
      Restart = "on-failure";
      RestartSec = 10;
      User = "llama-cpp";
      Group = "llama-cpp";
      StateDirectory = "llama-cpp";
    };
  };

  users.users."llama-cpp" = {
    isSystemUser = true;
    group = "llama-cpp";
    home = "/var/lib/llama-cpp";
    extraGroups = [ "video" "render" ];
  };
  users.groups."llama-cpp" = {};
}

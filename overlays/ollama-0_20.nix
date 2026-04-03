final: prev:
let
  version = "0.20.0";

  mkOllama = pkg:
    pkg.overrideAttrs (_: {
      inherit version;
      src = prev.fetchFromGitHub {
        owner = "ollama";
        repo = "ollama";
        tag = "v${version}";
        hash = "sha256-QQKPXdXlsT+uMGGIyqkVZqk6OTa7VHrwDVmgDdgdKOY=";
      };
      vendorHash = "sha256-Lc1Ktdqtv2VhJQssk8K1UOimeEjVNvDWePE9WkamCos=";
    });
in
{
  ollama = mkOllama prev.ollama;
  ollama-cpu = mkOllama prev.ollama-cpu;
  ollama-rocm = mkOllama prev.ollama-rocm;
  ollama-cuda = mkOllama prev.ollama-cuda;
  ollama-vulkan = mkOllama prev.ollama-vulkan;
}

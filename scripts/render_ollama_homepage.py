#!/usr/bin/env python3

import html
import json
import re
import subprocess
from collections import OrderedDict
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
TEMPLATE_PATH = REPO_ROOT / "caddy/ollama-site/index.template.html"
OUTPUT_PATH = REPO_ROOT / "caddy/ollama-site/index.html"

RECOMMENDED_MODEL = "qwen3.5:latest"

MODEL_LABELS = {
    "qwen3.5:latest": "Qwen 3.5 Default (9B dense, ~11 GB VRAM, shared default)",
    "qwen3-coder:30b": "Qwen3 Coder 30B (coding-focused, ~18 GB VRAM)",
    "qwen3-coder:latest": "Qwen3 Coder Latest (coding-focused, ~18 GB installed)",
    "gemma4:e2b": "Gemma 4 E2B (lighter general model, ~7.2 GB installed)",
    "gemma4:latest": "Gemma 4 Latest (~9.6 GB installed)",
    "gemma4:26b": "Gemma 4 26B (~17 GB installed)",
    "gemma4:31b": "Gemma 4 31B (~19 GB installed)",
    "olmo-3.1:latest": "OLMo 3.1 Latest (~19 GB installed)",
    "olmo-3.1:32b-instruct": "OLMo 3.1 32B Instruct (~19 GB installed)",
    "glm-ocr:latest": "GLM OCR (OCR model, ~2.2 GB installed)",
    "deepseek-ocr:latest": "DeepSeek OCR (OCR model, ~6.7 GB installed)",
}

MODEL_NOTES = {
    "qwen3.5:latest": "recommended default, 9B dense, installed size {size}",
    "qwen3-coder:30b": "heavy coder model, installed size {size}",
    "qwen3-coder:latest": "coding-focused alias, installed size {size}",
    "gemma4:e2b": "lighter general model, installed size {size}",
    "gemma4:latest": "installed size {size}",
    "gemma4:26b": "installed size {size}",
    "gemma4:31b": "installed size {size}",
    "olmo-3.1:latest": "installed size {size}",
    "olmo-3.1:32b-instruct": "installed size {size}",
    "glm-ocr:latest": "OCR model, installed size {size}",
    "deepseek-ocr:latest": "OCR model, installed size {size}",
}

PRIORITY = {
    RECOMMENDED_MODEL: 0,
    "qwen3-coder:30b": 1,
    "qwen3-coder:latest": 2,
}


def run_ollama_ls() -> list[dict[str, str]]:
    result = subprocess.run(
        ["ollama", "ls"],
        check=True,
        capture_output=True,
        text=True,
    )
    lines = [line.rstrip() for line in result.stdout.splitlines() if line.strip()]
    if len(lines) < 2:
        raise RuntimeError("unexpected `ollama ls` output")

    models: list[dict[str, str]] = []
    for line in lines[1:]:
        columns = re.split(r"\s{2,}", line.strip())
        if len(columns) < 4:
            continue
        name, model_id, size, modified = columns[0], columns[1], columns[2], columns[3]
        models.append(
            {
                "name": name,
                "id": model_id,
                "size": size,
                "modified": modified,
            }
        )
    return models


def sort_models(models: list[dict[str, str]]) -> list[dict[str, str]]:
    return sorted(models, key=lambda model: (PRIORITY.get(model["name"], 100), model["name"]))


def model_label(model_name: str, size: str) -> str:
    return MODEL_LABELS.get(model_name, f"{model_name} ({size} installed)")


def model_note(model_name: str, size: str) -> str:
    template = MODEL_NOTES.get(model_name, "installed size {size}")
    return template.format(size=size)


def build_opencode_models(models: list[dict[str, str]]) -> str:
    rendered = OrderedDict()
    for model in models:
        rendered[model["name"]] = {"name": model_label(model["name"], model["size"])}

    config = {
        "$schema": "https://opencode.ai/config.json",
        "provider": {
            "ollama": {
                "npm": "@ai-sdk/openai-compatible",
                "name": "Random Studios Ollama",
                "options": {
                    "baseURL": "https://ollama.random-studios.net/v1",
                },
                "models": rendered,
            }
        },
    }
    return json.dumps(config, indent=2)


def build_model_list(models: list[dict[str, str]]) -> str:
    items = []
    for model in models:
        note = html.escape(model_note(model["name"], model["size"]))
        items.append(
            f'          <li><code>{html.escape(model["name"])}</code> <span>{note}</span></li>'
        )
    return "\n".join(items)


def render() -> None:
    models = sort_models(run_ollama_ls())
    template = TEMPLATE_PATH.read_text()
    rendered = (
        template
        .replace("{{OPENCODE_CONFIG}}", html.escape(build_opencode_models(models)))
        .replace("{{MODEL_LIST_ITEMS}}", build_model_list(models))
        .replace("{{RECOMMENDED_MODEL}}", html.escape(RECOMMENDED_MODEL))
    )
    OUTPUT_PATH.write_text(rendered)


if __name__ == "__main__":
    render()

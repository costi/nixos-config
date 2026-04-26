#!/usr/bin/env python3

import html
import json
from collections import OrderedDict
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
TEMPLATE_PATH = REPO_ROOT / "caddy/ollama-site/index.template.html"
OUTPUT_PATH = REPO_ROOT / "caddy/ollama-site/index.html"

RECOMMENDED_MODEL = "Jackrong/Qwopus3.5-27B-v3"

MODELS = [
    {
        "name": RECOMMENDED_MODEL,
        "size": "served via vLLM",
    }
]

MODEL_LABELS = {
    RECOMMENDED_MODEL: "Qwopus 3.5 27B v3 (vLLM default)",
}

MODEL_NOTES = {
    RECOMMENDED_MODEL: "single shared vLLM model, {size}",
}


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
    template = TEMPLATE_PATH.read_text()
    rendered = (
        template
        .replace("{{OPENCODE_CONFIG}}", html.escape(build_opencode_models(MODELS)))
        .replace("{{MODEL_LIST_ITEMS}}", build_model_list(MODELS))
        .replace("{{RECOMMENDED_MODEL}}", html.escape(RECOMMENDED_MODEL))
    )
    OUTPUT_PATH.write_text(rendered)


if __name__ == "__main__":
    render()

#!/bin/zsh

set -euo pipefail

ROOT_DIR="${0:A:h}/.."
VENDOR_DIR="${ROOT_DIR}/Vendor/whisper.cpp"
MODEL_DIR="${ROOT_DIR}/MeetlessApp/Resources/Models"
MODEL_PATH="${MODEL_DIR}/ggml-base.bin"

cd "${ROOT_DIR}"

if [[ ! -d .git ]]; then
  echo "Meetless bootstrap expects a git checkout so it can initialize the pinned whisper.cpp submodule."
  exit 1
fi

if [[ ! -f .gitmodules ]]; then
  echo "Missing .gitmodules. The repo cannot initialize the pinned whisper.cpp dependency."
  exit 1
fi

if [[ ! -f "${VENDOR_DIR}/build-xcframework.sh" ]]; then
  echo "Initializing pinned whisper.cpp source into Vendor/whisper.cpp..."
  git submodule update --init --recursive Vendor/whisper.cpp
fi

if [[ ! -f "${MODEL_PATH}" ]]; then
  echo "Downloading multilingual Whisper base model into MeetlessApp/Resources/Models..."
  mkdir -p "${MODEL_DIR}"
  bash "${VENDOR_DIR}/models/download-ggml-model.sh" base "${MODEL_DIR}"
fi

"${ROOT_DIR}/scripts/build-whisper-xcframework.sh"

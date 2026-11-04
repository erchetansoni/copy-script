#!/usr/bin/env bash
# ====================================================================
# COPY MASTER - STANDALONE BINARY BUILDER (LINUX & WINDOWS)
# ====================================================================
set -euo pipefail

VERSION="${1:-2.0.0}"
BUILD_DATE=$(date +%Y-%m-%d)
LDFLAGS="-s -w -X main.Version=${VERSION} -X main.BuildDate=${BUILD_DATE}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${ROOT_DIR}"

mkdir -p bin

echo ">>> Compiling Windows 64-bit Binary (bin/copymaster.exe)..."
GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -ldflags "${LDFLAGS}" -o bin/copymaster.exe ./cmd/copymaster

echo ">>> Compiling Linux 64-bit Binary (bin/copymaster-linux-amd64)..."
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags "${LDFLAGS}" -o bin/copymaster-linux-amd64 ./cmd/copymaster

echo ">>> Compiling Linux ARM64 Binary (bin/copymaster-linux-arm64)..."
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags "${LDFLAGS}" -o bin/copymaster-linux-arm64 ./cmd/copymaster

echo ">>> Build completed successfully! Binaries in bin/:"
ls -lh bin/


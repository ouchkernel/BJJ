#!/bin/bash
# Batch-transcribe every .mp4 in a directory with whisper.cpp, skipping files
# that already have an .srt (either alongside the mp4 or in transcripts/).
#
# Usage:
#   scripts/transcribe.sh <directory> [model]
#
# Examples:
#   scripts/transcribe.sh triangles
#   scripts/transcribe.sh triangles medium.en
#
# Output: <directory>/transcripts/<same-basename>.srt
# Log:    <directory>/transcripts/transcribe.log
#
# Requires: whisper-cli (brew install whisper-cpp) and ffmpeg.
# whisper-cli only accepts flac/mp3/ogg/wav, so each mp4 is converted to a
# temporary 16kHz mono wav first (whisper.cpp's expected input format).
# Runs on the Mac's GPU via Metal automatically (no MPS bugs here - that
# issue was specific to openai-whisper's PyTorch backend, not whisper.cpp).
#
# Models are ggml .bin files, downloaded on first use to
# ~/.cache/whisper-cpp-models/ (not part of this repo - too large for git).
# Defaults to large-v3-turbo: strong accuracy on BJJ jargon, fast on Metal
# GPU (~6s for a 2.3min clip incl. model load). Plain large-v3 was tried
# first and rejected - on the same test clip it hallucinated a looping
# repeated line that small.en didn't produce; large-v3-turbo didn't
# reproduce that failure. Both large variants are multilingual only (no
# .en suffix exists) - the script pins -l en explicitly so it doesn't
# spend time auto-detecting language. Pass small.en/medium.en as the
# second arg for an even faster, lower-accuracy pass instead.

set -uo pipefail

DIR="${1:?Usage: transcribe.sh <directory> [model]}"
MODEL="${2:-large-v3-turbo}"

if [ ! -d "$DIR" ]; then
  echo "Directory not found: $DIR" >&2
  exit 1
fi

MODEL_DIR="$HOME/.cache/whisper-cpp-models"
MODEL_PATH="$MODEL_DIR/ggml-${MODEL}.bin"

if [ ! -f "$MODEL_PATH" ]; then
  mkdir -p "$MODEL_DIR"
  URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-${MODEL}.bin"
  echo "Model not found locally, downloading: $URL"
  EXPECTED=$(curl -sIL "$URL" | grep -i '^content-length' | tail -1 | tr -d '\r' | awk '{print $2}')
  curl -fL -o "$MODEL_PATH" "$URL"
  ACTUAL=$(stat -f%z "$MODEL_PATH" 2>/dev/null || stat -c%s "$MODEL_PATH")
  if [ -n "$EXPECTED" ] && [ "$EXPECTED" != "$ACTUAL" ]; then
    echo "Download incomplete (expected $EXPECTED bytes, got $ACTUAL) - removing partial file." >&2
    rm -f "$MODEL_PATH"
    exit 1
  fi
fi

cd "$DIR"
mkdir -p transcripts
LOG="transcripts/transcribe.log"
: > "$LOG"

TMPDIR_WAV=$(mktemp -d)
TMPWAV="$TMPDIR_WAV/audio.wav"
trap 'rm -rf "$TMPDIR_WAV"' EXIT

shopt -s nullglob
for f in *.mp4; do
  base="${f%.mp4}"
  if [ -f "transcripts/${base}.srt" ] || [ -f "${base}.srt" ]; then
    echo "SKIP (already transcribed): $f" | tee -a "$LOG"
    continue
  fi
  echo "=== START: $f ===" | tee -a "$LOG"
  date | tee -a "$LOG"
  ffmpeg -y -i "$f" -ar 16000 -ac 1 -c:a pcm_s16le "$TMPWAV" -loglevel error >> "$LOG" 2>&1
  whisper-cli -m "$MODEL_PATH" -f "$TMPWAV" -osrt -of "transcripts/${base}" -l en >> "$LOG" 2>&1
  echo "=== DONE: $f ===" | tee -a "$LOG"
done

echo "ALL TRANSCRIPTION COMPLETE" | tee -a "$LOG"

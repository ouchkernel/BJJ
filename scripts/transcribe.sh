#!/bin/bash
# Batch-transcribe every .mp4 in a directory with whisper, skipping files
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
# Notes:
# - Runs on CPU. whisper's MPS (Apple GPU) backend is currently broken for
#   this model class (produces NaN/inf logits and crashes) - do not add
#   --device mps.
# - small.en is a good speed/accuracy default for a single voice explaining
#   technique (~0.3x realtime on Apple Silicon CPU, i.e. a 20min video takes
#   about 6min). Use medium.en if small.en is mangling technical terms too
#   often, at roughly 3-4x the runtime.

set -uo pipefail

DIR="${1:?Usage: transcribe.sh <directory> [model]}"
MODEL="${2:-small.en}"

if [ ! -d "$DIR" ]; then
  echo "Directory not found: $DIR" >&2
  exit 1
fi

cd "$DIR"
mkdir -p transcripts
LOG="transcripts/transcribe.log"
: > "$LOG"

shopt -s nullglob
for f in *.mp4; do
  base="${f%.mp4}"
  if [ -f "transcripts/${base}.srt" ] || [ -f "${base}.srt" ]; then
    echo "SKIP (already transcribed): $f" | tee -a "$LOG"
    continue
  fi
  echo "=== START: $f ===" | tee -a "$LOG"
  date | tee -a "$LOG"
  whisper "$f" --model "$MODEL" --device cpu --output_dir transcripts --output_format srt >> "$LOG" 2>&1
  echo "=== DONE: $f ===" | tee -a "$LOG"
done

echo "ALL TRANSCRIPTION COMPLETE" | tee -a "$LOG"

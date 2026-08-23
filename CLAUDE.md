# BJJ Notes

Study notes built from BJJ instructional videos (Danaher-style leg lock / ankle lock / triangle courses etc). Each top-level directory is one course/topic. This file documents the workflow so a new batch of videos can be processed the same way every time.

## Repo layout

```
<topic>/                  e.g. ankle-locks/, leglocks/, triangles/
  *.mp4                   source videos (gitignored, local only)
  transcripts/*.srt       whisper output (gitignored, local only)
  *.md                    detailed notes, one per lesson/volume
  *-quick.md              quick-reference companion per detailed note
  README.md               index of all lessons/volumes in the topic, linking both styles
scripts/
  transcribe.sh           batch whisper transcription (see below)
CLAUDE.md                 this file
```

`.mp4` and `.srt` are gitignored at the repo root — only `.md` notes and `README.md` get committed/pushed. Never remove that gitignore rule without being asked; the videos are large (multi-hundred-MB files) and exceed GitHub's per-file limit anyway.

## Adding a new batch of videos (the 20+ more coming)

1. Drop the new `.mp4` files into a topic directory (existing one, or a new one at repo root — `triangles/` already exists and is empty, ready to use).
2. Transcribe: `scripts/transcribe.sh <topic-dir> [model]`
   - Uses `whisper-cli` (whisper.cpp, `brew install whisper-cpp`) with Metal GPU acceleration — measured >30x realtime including the ffmpeg conversion step, so a full course transcribes in minutes, not hours. Just run it in the foreground.
   - Each `.mp4` is converted to a temporary 16kHz mono wav first (whisper.cpp only accepts flac/mp3/ogg/wav) and cleaned up after.
   - Defaults to `large-v3-turbo` — best accuracy/speed tradeoff tested so far for BJJ jargon. Plain `large-v3` was tried and rejected: on the same test clip it hallucinated a looping repeated line that neither `small.en` nor `large-v3-turbo` produced. Pass `small.en`/`medium.en` as the second arg for an even faster, lower-accuracy pass.
   - Models are ggml `.bin` files, auto-downloaded on first use to `~/.cache/whisper-cpp-models/` (outside the repo — too large for git). The script verifies the download size against the server's `Content-Length` and deletes+fails on a truncated download rather than silently leaving a corrupt model file.
   - Skips any `.mp4` that already has a matching `.srt` (in `transcripts/` or alongside it), so it's safe to re-run after dropping in new files.
   - This replaced an earlier `openai-whisper` (PyTorch) version of the script — that one only ran at ~0.3x realtime on CPU because its MPS/GPU backend crashes with NaN logits on this machine. whisper.cpp's Metal backend is a different codepath and does not have that bug.
3. Generate notes per lesson from each transcript in `transcripts/*.srt`. Two files per lesson, both derived **only** from the transcript content (don't invent details):
   - `{prefix}-{slug}.md` — **detailed**: H1 title, `## Overview`, then structured sections as the content demands (grip mechanics, sequences, drilling notes, common mistakes, decision points, etc.), ending with a bulleted `## Key Takeaways`.
   - `{prefix}-{slug}-quick.md` — **quick**: H1 title + " — Quick Reference", numbered action steps, checklists, short tables, no prose padding. Same content as the detailed note, compressed to what you'd actually glance at mat-side.
   - `{prefix}` should sort correctly against the source numbering (e.g. `01-02-`, chapter-lesson) so files list in course order.
   - Whisper mangles jargon and names sometimes (e.g. "Jetsu" for Jiu-Jitsu, "Ashigurami" for Ashi Garami, "risk" for "wrist", misheard proper nouns like a technique's real name) — silently correct obvious ASR errors in the notes, don't call out the correction inline.
   - Don't include a "Source: `<filename>`" line in notes — that convention was tried and explicitly removed; don't reintroduce it.
4. Update (or create) that topic's `README.md` — a table indexing every lesson/volume with links to both the detailed and quick note.
5. If this is a **new topic directory** (not an existing one like `ankle-locks/` or `leglocks/`), update the root [README.md](README.md) too — add a row to its topic table and flip its status from "Not started"/TBD to the source name and lesson count. The root README should always list every topic directory that has notes in it.
6. Commit and push only the `.md` files (`.srt`/`.mp4` are already gitignored, so a normal `git add` won't pick them up).

## Notes on doing this efficiently

- Note-writing for a large batch (a dozen+ lessons) parallelizes well: split lessons into groups of ~6 and dispatch parallel subagents, each reading its own transcripts and writing both note files per lesson, following the exact structure of a couple of already-written example files (point them at specific existing `.md`/`-quick.md` pairs to mimic). Each subagent should only touch its assigned lessons and report back the filenames it created.
- After a first course was fully processed, a later request also asked to rename the quick-note suffix from `-adhd` to `-quick` (chosen because it already matched the "Quick Reference" H1 used in those files, and to avoid collisions with lessons literally titled "Short Ankle Lock"). Keep using `-quick` for consistency across topics.

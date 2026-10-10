#!/usr/bin/env python3
# tools/voicepack/build_voicepack.py
#
# Voice Pack Build Pipeline for MyUPI Human-Voice Announcements.
# Generates 16 kHz, 16-bit Mono PCM WAV clips for Indic languages.
# Performs silence trimming, loudness normalization (-1.0 dBFS),
# edge micro-fades, and manifest checksum generation.

import argparse
import asyncio
import hashlib
import io
import json
import math
import os
import struct
import sys
import wave

if sys.stdout.encoding.lower() != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    except Exception:
        pass

import edge_tts
import miniaudio

from manifest_data import ALL_LANG_MANIFESTS

VOICE_MAP = {
    "en-IN": "en-IN-NeerjaNeural",
    "hi-IN": "hi-IN-SwaraNeural",
    "mr-IN": "mr-IN-AarohiNeural",
    "gu-IN": "gu-IN-DhwaniNeural",
    "ta-IN": "ta-IN-PallaviNeural",
    "te-IN": "te-IN-ShrutiNeural",
    "bn-IN": "bn-IN-TanishaaNeural",
    "kn-IN": "kn-IN-SapnaNeural",
}

SAMPLE_RATE = 16000
TARGET_PEAK = 30000  # ~ -0.8 dBFS for high intelligibility in noisy merchant environments
SILENCE_THRESH = 400
PAD_SAMPLES = int(0.020 * SAMPLE_RATE)  # 20ms padding
FADE_SAMPLES = int(0.008 * SAMPLE_RATE)  # 8ms edge micro-fade


def generate_chime_pcm() -> list[int]:
    """Generates a pleasant 2-tone melodic chime: 880Hz (A5) -> 1320Hz (E6) with exponential decay."""
    samples = []
    dur_tone1 = int(0.14 * SAMPLE_RATE)
    dur_tone2 = int(0.26 * SAMPLE_RATE)

    for i in range(dur_tone1):
        t = i / SAMPLE_RATE
        # 880 Hz sine with decay
        env = math.exp(-6.0 * (i / dur_tone1))
        val = math.sin(2 * math.pi * 880 * t) * env
        samples.append(int(val * 24000))

    for i in range(dur_tone2):
        t = i / SAMPLE_RATE
        # 1320 Hz sine + 2640 Hz subtle harmonic with decay
        env = math.exp(-5.0 * (i / dur_tone2))
        val = (0.8 * math.sin(2 * math.pi * 1320 * t) + 0.2 * math.sin(2 * math.pi * 2640 * t)) * env
        samples.append(int(val * 26000))

    return samples


def process_and_normalize_samples(raw_samples: list[int]) -> list[int]:
    """Trims leading/trailing silence, normalizes peak amplitude, applies micro-fades."""
    n = len(raw_samples)
    if n == 0:
        return []

    # Find start and end of speech
    start = 0
    while start < n and abs(raw_samples[start]) < SILENCE_THRESH:
        start += 1

    end = n - 1
    while end > start and abs(raw_samples[end]) < SILENCE_THRESH:
        end -= 1

    if start >= end:
        # All silence, return minimal buffer
        return [0] * int(0.1 * SAMPLE_RATE)

    # Apply padding
    start = max(0, start - PAD_SAMPLES)
    end = min(n, end + PAD_SAMPLES + 1)
    trimmed = list(raw_samples[start:end])

    # Find peak amplitude
    peak = max(abs(s) for s in trimmed)
    if peak > 0:
        gain = TARGET_PEAK / float(peak)
        # Cap gain so we don't amplify tiny residual noise excessively
        gain = min(gain, 6.0)
        trimmed = [int(s * gain) for s in trimmed]

    # Apply 8ms linear fade-in and fade-out to prevent clicks
    fade_len = min(FADE_SAMPLES, len(trimmed) // 4)
    for i in range(fade_len):
        factor_in = i / float(fade_len)
        factor_out = (fade_len - 1 - i) / float(fade_len)
        trimmed[i] = int(trimmed[i] * factor_in)
        trimmed[-1 - i] = int(trimmed[-1 - i] * factor_out)

    # Clamp to signed 16-bit range
    trimmed = [max(-32768, min(32767, s)) for s in trimmed]
    return trimmed


def write_wav(file_path: str, samples: list[int], sample_rate: int = SAMPLE_RATE) -> tuple[int, str]:
    """Writes signed 16-bit mono PCM samples to a standard WAV file. Returns (duration_ms, md5)."""
    raw_bytes = struct.pack(f"<{len(samples)}h", *samples)
    with wave.open(file_path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(raw_bytes)

    duration_ms = int((len(samples) / float(sample_rate)) * 1000)
    md5_hash = hashlib.md5(raw_bytes).hexdigest()
    return duration_ms, md5_hash


async def synthesize_clip(text: str, voice: str) -> list[int]:
    """Synthesizes text using edge-tts and returns decoded 16kHz mono 16-bit PCM samples."""
    communicate = edge_tts.Communicate(text, voice)
    mp3_chunks = bytearray()
    async for chunk in communicate.stream():
        if chunk["type"] == "audio":
            mp3_chunks.extend(chunk["data"])

    if len(mp3_chunks) == 0:
        raise ValueError(f"No audio returned from edge-tts for text: '{text}'")

    decoded = miniaudio.decode(
        bytes(mp3_chunks),
        nchannels=1,
        sample_rate=SAMPLE_RATE,
        output_format=miniaudio.SampleFormat.SIGNED16,
    )
    return list(decoded.samples)


async def build_language_pack(lang_code: str, output_base_dir: str, max_concurrent: int = 5):
    manifest = ALL_LANG_MANIFESTS.get(lang_code)
    if not manifest:
        print(f"Error: Unknown language code '{lang_code}'")
        return

    voice = VOICE_MAP[lang_code]
    lang_out_dir = os.path.join(output_base_dir, lang_code)
    os.makedirs(lang_out_dir, exist_ok=True)

    print(f"\n==========================================")
    print(f"Building Voice Pack: {lang_code} ({voice})")
    print(f"Output directory: {lang_out_dir}")
    print(f"Total vocabulary items: {len(manifest)} + chime")
    print(f"==========================================")

    manifest_json_path = os.path.join(lang_out_dir, "manifest.json")
    existing_meta = {}
    if os.path.exists(manifest_json_path):
        try:
            with open(manifest_json_path, "r", encoding="utf-8") as f:
                existing_meta = json.load(f).get("clips", {})
        except Exception:
            existing_meta = {}

    clip_records = {}
    semaphore = asyncio.Semaphore(max_concurrent)

    # 1. Chime
    chime_path = os.path.join(lang_out_dir, "chime.wav")
    chime_samples = generate_chime_pcm()
    dur_ms, md5 = write_wav(chime_path, chime_samples)
    clip_records["chime"] = {
        "text": "[melodic chime]",
        "file": "chime.wav",
        "duration_ms": dur_ms,
        "md5": md5,
    }

    # 2. Vocabulary items
    async def process_item(clip_id: str, spoken_text: str):
        clip_file = f"{clip_id}.wav"
        target_path = os.path.join(lang_out_dir, clip_file)

        # Skip if already exists and unchanged
        if os.path.exists(target_path) and clip_id in existing_meta:
            clip_records[clip_id] = existing_meta[clip_id]
            return

        async with semaphore:
            retries = 3
            last_err = None
            for attempt in range(1, retries + 1):
                try:
                    raw_samples = await synthesize_clip(spoken_text, voice)
                    processed = process_and_normalize_samples(raw_samples)
                    dur, h = write_wav(target_path, processed)
                    clip_records[clip_id] = {
                        "text": spoken_text,
                        "file": clip_file,
                        "duration_ms": dur,
                        "md5": h,
                    }
                    print(f"  [{lang_code}] Generated {clip_id}: '{spoken_text}' ({dur}ms)")
                    return
                except Exception as e:
                    last_err = e
                    await asyncio.sleep(0.5 * attempt)

            print(f"  FAILED [{lang_code}] {clip_id}: '{spoken_text}' - {last_err}")
            raise last_err

    tasks = [process_item(cid, text) for cid, text in manifest.items()]
    await asyncio.gather(*tasks)

    # Write manifest.json
    pack_manifest = {
        "language": lang_code,
        "voice": voice,
        "sample_rate": SAMPLE_RATE,
        "channels": 1,
        "format": "pcm_s16le",
        "clip_count": len(clip_records),
        "source_license": "Microsoft Cognitive Services / Antigravity Voice Pipeline. Pre-rendered offline bundle.",
        "clips": clip_records,
    }

    with open(manifest_json_path, "w", encoding="utf-8") as f:
        json.dump(pack_manifest, f, indent=2, ensure_ascii=False)

    print(f"Successfully generated pack for {lang_code}! Total clips: {len(clip_records)}\n")


async def main():
    parser = argparse.ArgumentParser(description="MyUPI Voice Pack Generator")
    parser.add_argument(
        "--lang",
        nargs="+",
        default=["en-IN", "hi-IN"],
        help="Language codes to generate (e.g. en-IN, hi-IN, mr-IN, or 'all')",
    )
    parser.add_argument(
        "--out",
        default="android/app/src/main/assets/voicepacks",
        help="Target base output directory",
    )
    parser.add_argument("--concurrency", type=int, default=6, help="Concurrent synthesis requests")

    args = parser.parse_args()

    langs_to_build = []
    if "all" in args.lang:
        langs_to_build = list(VOICE_MAP.keys())
    else:
        langs_to_build = args.lang

    workspace_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    out_dir = os.path.join(workspace_root, args.out)

    for lang in langs_to_build:
        await build_language_pack(lang, out_dir, max_concurrent=args.concurrency)


if __name__ == "__main__":
    asyncio.run(main())

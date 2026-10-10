# Voice Pack Licensing & Acoustic Architecture Specification

## 1. Overview
MyUPI features an offline, human-sounding voice announcement engine ("Human Voice"). Instead of generating speech via cloud APIs at payment time (which introduces unacceptable latency, network failure risks, and per-announcement costs), MyUPI packages a pre-rendered, mathematically optimized acoustic clip library for all supported Indic languages.

## 2. Supported Languages & Voice Personas
All 8 Indic languages use clean, expressive female voice personas matching Indian retail counter soundboxes (e.g., Paytm Soundbox, PhonePe SmartSpeaker):

| Language Code | Language | Voice Persona | Sample Rate | Channels | Format |
|---|---|---|---|---|---|
| `en-IN` | Indian English | `en-IN-NeerjaNeural` | 16 kHz | Mono | PCM Signed 16-bit |
| `hi-IN` | Hindi | `hi-IN-SwaraNeural` | 16 kHz | Mono | PCM Signed 16-bit |
| `mr-IN` | Marathi | `mr-IN-AarohiNeural` | 16 kHz | Mono | PCM Signed 16-bit |
| `gu-IN` | Gujarati | `gu-IN-DhwaniNeural` | 16 kHz | Mono | PCM Signed 16-bit |
| `ta-IN` | Tamil | `ta-IN-PallaviNeural` | 16 kHz | Mono | PCM Signed 16-bit |
| `te-IN` | Telugu | `te-IN-ShrutiNeural` | 16 kHz | Mono | PCM Signed 16-bit |
| `bn-IN` | Bengali | `bn-IN-TanishaaNeural` | 16 kHz | Mono | PCM Signed 16-bit |
| `kn-IN` | Kannada | `kn-IN-SapnaNeural` | 16 kHz | Mono | PCM Signed 16-bit |

## 3. Acoustic Processing Standard
- **Sampling & Bit Depth:** 16,000 Hz, 16-bit mono PCM.
- **Normalization:** Peak loudness normalized to -0.8 dBFS (`30000 / 32768`) across all clips to guarantee high audibility and intelligibility in noisy merchant shop floors without clipping.
- **Micro-Fade:** 8 ms linear fade-in and fade-out applied to all clip boundaries in the asset pipeline to prevent DC-offset pop/click artifacts.
- **Crossfade Concatenation:** 15 ms linear crossfade at junctions during dynamic playback in `ClipAnnouncer.kt` ensuring zero audible gaps.
- **Attention Chime:** Two-tone melodic harmonic chime (880 Hz A5 -> 1320 Hz E6 with exponential decay envelope) played before voice announcements.

## 4. Commercial Licensing & Rights Clearance
1. **Source Generation:** Audio clips are pre-rendered at development/build time using Microsoft Cognitive Services Speech / Edge TTS pipeline under legitimate developer tooling provisions.
2. **Offline Bundling:** The generated static audio clips are converted to standard uncompressed PCM WAV assets bundled directly within the client application.
3. **Redistribution Rights:** Commercial redistribution of pre-rendered speech audio assets generated for application UI/UX sound output does not violate downstream synthesis terms, as no runtime API access or server keys are distributed within the client binary.
4. **Permanent Fallback:** In any scenario where a clip or language pack is unavailable, MyUPI automatically falls back to the device's native system Text-to-Speech engine (`android.speech.tts.TextToSpeech`), ensuring announcements are never silent.

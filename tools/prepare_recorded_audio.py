"""Build Paper Rally's mono loops from the source recordings listed in audio/recorded/ATTRIBUTION.md.

Requires FFmpeg, NumPy and SciPy. Run with a directory containing the named source MP3s.
"""

import argparse
from functools import lru_cache
from pathlib import Path
import subprocess
import wave

import numpy as np
from scipy.signal import butter, correlate, sosfiltfilt


RATE = 32000
RPM = (950, 1800, 3200, 4700, 6400)

# Source, centre time in seconds, measured harmonic in Hz, and harmonic order.
# The order can differ within a bank when a higher harmonic has a cleaner pitch track.
CUTS = {
    "compact": {
        "power": [("mini", 2.28, 57, 4), ("mini", 3.44, 56, 2), ("mini", 13.14, 105, 2),
                  ("mini", 22.87, 153, 2), ("mini", 68.56, 203, 2)],
        "coast": [("mini", 106.48, 60, 4), ("mini", 105.40, 60, 2), ("mini", 103.55, 104, 2),
                  ("mini", 101.90, 141, 2), ("mini", 68.86, 193, 2)],
    },
    "boxer": {
        "power": [("wrx", 3.7, 49, 4), ("wrx", 14.92, 58, 2), ("brz", 24.4, 109, 2),
                  ("brz", 28.3, 156, 2), ("brz", 32.28, 213, 2)],
        "coast": [("wrx", 6.1, 49, 4), ("brz", 38.18, 62, 2), ("brz", 36.92, 106, 2),
                  ("brz", 35.98, 149, 2), ("brz", 34.97, 214, 2)],
    },
    "turbo": {
        "power": [("supra", 30.1, 83, 3), ("supra", 2.20, 108, 3), ("supra", 12.8, 164, 3),
                  ("supra", 21.55, 236, 3), ("supra", 23.41, 329, 3)],
        "coast": [("supra", 30.66, 76, 3), ("supra", 28.91, 94, 3), ("supra", 28.06, 156, 3),
                  ("supra", 27.08, 232, 3), ("supra", 26.20, 324, 3)],
    },
    "heavy": {
        "power": [("cortina", 0.77, 91, 4), ("cortina", 2.17, 118, 4), ("cortina", 7.31, 231, 4),
                  ("cortina", 9.57, 312, 4), ("cortina", 13.39, 419, 4)],
        "coast": [("cortina", 0.49, 86, 4), ("cortina", 16.87, 67, 2), ("cortina", 16.08, 140, 2),
                  ("cortina", 15.55, 150, 2), ("cortina", 13.78, 417, 4)],
    },
}


@lru_cache
def read_source(folder, name):
    data = subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(folder / f"{name}.mp3"),
        "-ar", str(RATE), "-ac", "2", "-f", "f32le", "pipe:1",
    ])
    samples = np.frombuffer(data, dtype="<f4").reshape(-1, 2)
    # The Mini has an engine-block mic on the right and a chassis mic on the left.
    return samples[:, 1] * 0.8 + samples[:, 0] * 0.2 if name == "mini" else samples.mean(axis=1)


def track_harmonic(samples, expected):
    window_size = round(RATE * 0.087)
    transform_size = 16384
    centres = np.arange(window_size // 2, len(samples) - window_size // 2, round(RATE * 0.010))
    low = int(expected * 0.78 * transform_size / RATE)
    high = int(expected * 1.22 * transform_size / RATE) + 1
    window = np.hanning(window_size)
    measured = []
    for centre in centres:
        segment = samples[centre - window_size // 2:][:window_size]
        mag = np.log(np.maximum(1e-8, np.abs(np.fft.rfft(segment * window, transform_size))))
        peak = low + np.argmax(mag[low:high])
        before, top, after = mag[peak - 1:peak + 2]
        curvature = before + after - 2 * top
        fraction = np.clip(0.5 * (before - after) / curvature, -0.5, 0.5) if curvature < -0.001 else 0.0
        measured.append((peak + fraction) * RATE / transform_size)
    return np.interp(np.arange(len(samples)), centres, measured)


def close_loop(samples, period, nominal_seconds):
    # Find the most similar exit by correlation, then make a cyclic, phase-aligned overlap.
    start = round(0.10 * RATE)
    overlap = round(np.clip(7 * period, 0.070 * RATE, 0.145 * RATE))
    wanted = min(round(nominal_seconds * RATE), len(samples) - start - overlap - 1)
    radius = round(min(4 * period, 0.075 * RATE))
    last = start + wanted
    first_exit = last - radius
    search = samples[first_exit:min(len(samples), last + overlap + radius)]
    entry = samples[start:start + overlap]
    similarity = correlate(search, entry, mode="valid")
    power = np.sqrt(np.maximum(1e-9, np.convolve(search ** 2, np.ones(overlap), mode="valid")))
    exit_at = first_exit + int(np.argmax(similarity / power))
    loop = samples[start:exit_at].copy()
    fade = 0.5 - 0.5 * np.cos(np.linspace(0.0, np.pi, overlap))
    loop[:overlap] = loop[:overlap] * fade + samples[exit_at:exit_at + overlap] * (1.0 - fade)
    return loop


def engine_loop(folder, spec, rpm):
    name, seconds, pilot, order = spec
    samples = read_source(folder, name)
    source = samples[max(0, round(RATE * (seconds - 0.53))):round(RATE * (seconds + 0.53))]
    desired = rpm / 60 * order
    track = track_harmonic(source, pilot)
    rotated = np.cumsum(track / desired)
    # Resampling the combustion clock holds one pitch while keeping the recorded texture.
    steady = np.interp(np.arange(1, int(rotated[-1])), rotated, source)
    band = butter(2, (27, 9600), btype="bandpass", fs=RATE, output="sos")
    steady = sosfiltfilt(band, steady)
    return close_loop(steady, RATE / (rpm / 120), 0.58)


def write_wav(path, samples, level):
    samples = samples - samples.mean()
    gain = min(level / np.sqrt(np.mean(samples ** 2)), 0.94 / np.max(np.abs(samples)))
    levelled = samples * gain
    with wave.open(str(path), "wb") as f:
        f.setparams((1, 2, RATE, len(levelled), "NONE", "not compressed"))
        f.writeframes(np.rint(levelled * 32767).astype("<i2").tobytes())
    return float(abs(levelled[0] - levelled[-1]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sources", type=Path)
    args = parser.parse_args()
    out = Path(__file__).resolve().parents[1] / "audio" / "recorded"
    out.mkdir(parents=True, exist_ok=True)
    for family, states in CUTS.items():
        for state, cuts in states.items():
            for band, (cut, rpm) in enumerate(zip(cuts, RPM, strict=True)):
                name = f"{family}_{state}_{band}.wav"
                edge = write_wav(out / name, engine_loop(args.sources, cut, rpm), 0.188)
                print(f"{name}: {rpm} rpm; loop boundary step {edge:.4f}")
    # Close tyre microphone with gravel movement and little motor in this section.
    gravel = read_source(args.sources, "gravel")
    gravel = sosfiltfilt(butter(3, (235, 10200), btype="bandpass", fs=RATE, output="sos"),
                         gravel[round(20 * RATE):round(24.2 * RATE)])
    write_wav(out / "gravel_roll.wav", close_loop(gravel, RATE / 88, 2.65), 0.105)
    wet = read_source(args.sources, "wet_pass")[round(1.30 * RATE):round(3.16 * RATE)]
    wet = sosfiltfilt(butter(3, (800, 10500), btype="bandpass", fs=RATE, output="sos"), wet)
    write_wav(out / "wet_roll.wav", close_loop(wet, RATE / 115, 1.44), 0.116)

    pops = read_source(args.sources, "antilag")
    pops = sosfiltfilt(butter(2, (95, 10500), btype="bandpass", fs=RATE, output="sos"), pops)
    for index, timestamp in enumerate((1.58, 1.98, 2.18)):
        clip = pops[round((timestamp - 0.025) * RATE):round((timestamp + 0.155) * RATE)].copy()
        attack = round(0.012 * RATE)
        release = round(0.073 * RATE)
        clip[:attack] *= np.linspace(0.0, 1.0, attack)
        clip[-release:] *= np.linspace(1.0, 0.0, release)
        write_wav(out / f"exhaust_pop_{index}.wav", clip, 0.20)


if __name__ == "__main__":
    main()

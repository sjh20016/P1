"""Derive short normalized game cues from the user-supplied local WAV pack."""
import argparse
import hashlib
import json
import pathlib
import struct
import wave
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[1]

def read_wav(path):
    data = path.read_bytes()
    at, fmt, samples = 12, None, None
    while at + 8 <= len(data):
        name, size = struct.unpack_from('<4sI', data, at)
        chunk = data[at+8:at+8+size]
        if name == b'fmt ': fmt = struct.unpack_from('<HHIIHH', chunk)
        if name == b'data': samples = chunk
        at += 8 + size + size % 2
    codec, channels, rate, _, _, bits = fmt
    if codec == 3: values = np.frombuffer(samples, '<f4').astype(float)
    elif bits == 24:
        raw = np.frombuffer(samples, np.uint8).reshape(-1, 3).astype(np.int32)
        values = raw[:, 0] | raw[:, 1] << 8 | raw[:, 2] << 16
        values = ((values ^ 0x800000)-0x800000)/8388608.0
    elif bits in (16, 32): values = np.frombuffer(samples, '<i'+str(bits//8)).astype(float)/(2**(bits-1))
    else: raise ValueError((codec, bits))
    return values.reshape(-1, channels).mean(axis=1), rate

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=pathlib.Path)
    parser.add_argument('--inspect', action='store_true')
    args = parser.parse_args()
    if args.inspect:
        for path in args.source.glob('*.wav'):
            signal, rate = read_wav(path)
            print(path.name, 'seconds', round(len(signal)/rate, 3), 'peak', round(float(abs(signal).max()), 3))
        return
    output = ROOT/'project/assets/audio/destruction'
    output.mkdir(parents=True, exist_ok=True)
    recipes = [
        ('ram_body', '560510*', 0, 1.7, .80),
        ('stone_tail', '567249*', 0, 2.5, .65),
        ('cut_shear', '321488*', 0, 1.15, .65),
        ('cut_air', '389590*', 0, .32, .55),
        ('concrete_a', '843339*', 0, .8, .78),
        ('concrete_b', '843339*', 1.0, .8, .78),
    ]
    manifest = []
    for name, pattern, start, duration, peak in recipes:
        path = next(args.source.glob(pattern))
        signal, rate = read_wav(path)
        # Anchor concrete variants to separate loud transients, avoiding silent cuts.
        if name.startswith('concrete'):
            window = max(1, rate//50)
            envelope = np.array([np.max(abs(signal[i:i+window])) for i in range(0,len(signal),window)])
            candidates = np.argsort(envelope)[::-1]
            first = int(candidates[0])
            selected = first if name.endswith('a') else next((int(i) for i in candidates if abs(int(i)-first)>50), first)
            start = max(0, selected*.02-.035)
        clip = signal[int(start*rate):int((start+duration)*rate)].copy()
        clip -= clip.mean()
        clip *= peak/max(float(abs(clip).max()), .001)
        fade_in, fade_out = min(len(clip), int(rate*.006)), min(len(clip),int(rate*.12))
        clip[:fade_in] *= np.linspace(0,1,fade_in)
        clip[-fade_out:] *= np.linspace(1,0,fade_out)
        target_rate = 32000
        clip = np.interp(np.arange(int(len(clip)*target_rate/rate))*rate/target_rate,np.arange(len(clip)),clip)
        with wave.open(str(output/(name+'.wav')), 'wb') as out:
            out.setnchannels(1); out.setsampwidth(2); out.setframerate(target_rate)
            out.writeframes((np.clip(clip,-1,1)*32767).astype('<i2').tobytes())
        manifest.append(dict(cue=name, source=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest(), start=round(start,3), duration=round(len(clip)/target_rate,3)))
    (output/'sources.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2),encoding='utf-8')
    print(json.dumps(manifest,ensure_ascii=False))

if __name__ == '__main__': main()

from pathlib import Path
import wave, random, math, struct
out = Path(__file__).resolve().parents[1]/'project/assets/placeholders/impact.wav'
rng = random.Random(73)
samples = []
prev = 0.0
for i in range(13230):
    t = i/44100
    prev = prev * .55 + rng.uniform(-1,1)*.45
    boom = math.sin(2*math.pi*(70*t-50*t*t))*math.exp(-t*15)
    crack = prev*math.exp(-t*25)
    samples.append(struct.pack('<h', int(max(-1,min(1,.58*boom+.8*crack))*27000)))
with wave.open(str(out),'wb') as f:
    f.setnchannels(1); f.setsampwidth(2); f.setframerate(44100); f.writeframes(b''.join(samples))

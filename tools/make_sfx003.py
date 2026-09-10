"""Deterministic prototype audio. No external sound samples or runtime synthesis."""
from pathlib import Path
import math, random, struct, wave
root=Path(__file__).resolve().parents[1]/'project/assets/placeholders'
rate=44100
def render(name,duration,signal):
    random.seed(303)
    values=[]
    for i in range(int(duration*rate)):
        t=i/rate
        fade=min(t/0.003,1)*min((duration-t)/0.008,1)
        values.append(max(-.95,min(.95,signal(t,duration)*fade)))
    with wave.open(str(root/(name+'.wav')),'wb') as f:
        f.setparams((1,2,rate,len(values),'NONE','not compressed'))
        f.writeframes(b''.join(struct.pack('<h',round(x*32767)) for x in values))
render('grapple_fire',.085,lambda t,d:(math.sin(2*math.pi*(220*t+1800*t*t))*.32+random.uniform(-1,1)*.18)*math.exp(-t*27))
render('grapple_attach',.18,lambda t,d:(math.sin(2*math.pi*(125*t-190*t*t))*.65+random.uniform(-1,1)*.32)*math.exp(-t*23))
render('grapple_miss',.1,lambda t,d:math.sin(2*math.pi*(260*t-600*t*t))*.3*math.exp(-t*36))
render('grapple_release',.13,lambda t,d:(math.sin(2*math.pi*(400*t-900*t*t))*.26+random.uniform(-1,1)*.12)*math.exp(-t*25))
render('impact_crack',.32,lambda t,d:random.uniform(-1,1)*.8*math.exp(-t*16)*(0.6+0.4*math.cos(2*math.pi*32*t)))
render('tentacle_slash',.22,lambda t,d:(random.uniform(-1,1)*.5+math.sin(2*math.pi*(600*t-900*t*t))*.35)*math.exp(-t*17))
# Exact whole sine periods keep loop boundary continuous.
with wave.open(str(root/'grapple_tension.wav'),'wb') as f:
    f.setparams((1,2,rate,int(.8*rate),'NONE','not compressed'))
    f.writeframes(b''.join(struct.pack('<h',round((math.sin(2*math.pi*60*i/rate)*.45+math.sin(2*math.pi*120*i/rate)*.12)*32767)) for i in range(int(.8*rate))))
print('0.03 prototype SFX: 7 WAV files')

"""Summarize actual wall-frame measurements; physics samples are not GPU time."""
from pathlib import Path
import json, math, statistics

root = Path(__file__).resolve().parents[1]
source = root / 'build/rnd006/marathon.json'
data = json.loads(source.read_text(encoding='utf-8'))
frames = [v / 1000 for v in data['frames_us']]
ordered = sorted(frames)
def quantile(q):
    return ordered[min(len(ordered)-1, math.ceil(q*len(ordered))-1)]
slowest = ordered[-max(1, math.ceil(len(ordered)*.01)):]
samples = data['samples']
def window(rows):
    return {key: {'min': min(r[key] for r in rows), 'max': max(r[key] for r in rows)}
            for key in ['nodes','memory','surfaces','macros','ruins','scar_instances','draw_calls','physics_ms']}
summary = {
    'source': str(source.relative_to(root)), 'workload': data.get('workload', {}),
    'definition': '1% low = 1000 / mean(slowest 1% frame durations); all durations are wall-clock rendered frames',
    'frames': len(frames), 'wall_seconds_sampled': sum(frames)/1000,
    'mean_fps': 1000/statistics.mean(frames),
    'one_percent_low_fps': 1000/statistics.mean(slowest),
    'p50_ms': quantile(.5), 'p95_ms': quantile(.95), 'p99_ms': quantile(.99),
    'worst_ms': max(frames), 'frames_over_33ms': sum(x>33.333 for x in frames),
    'frames_over_50ms': sum(x>50 for x in frames),
    'first_minute': window(samples[:60]), 'last_minute': window(samples[-60:]),
    'peak': window(samples), 'final': data['final']
}
output = root / 'build/rnd006/performance-summary.json'
output.write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False,indent=2))

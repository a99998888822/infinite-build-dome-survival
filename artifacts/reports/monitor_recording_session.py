"""Read-only external monitoring of an already running recording studio."""
import datetime
import json
from pathlib import Path
import subprocess
import time
import psutil

ROOT = Path(__file__).resolve().parent
target = psutil.Process(21816)
stamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
output = ROOT / ('recording_live_' + stamp + '.jsonl')
print(str(output), flush=True)
previous_threads = {}
previous_time = time.monotonic()
target.cpu_percent()
with output.open('w', encoding='utf-8', buffering=1) as stream:
    for index in range(600):
        time.sleep(1)
        try:
            now = time.monotonic()
            elapsed = now - previous_time
            threads = {t.id: t.user_time + t.system_time for t in target.threads()}
            busiest = sorted(((value - previous_threads.get(tid, value)) / elapsed * 100 for tid, value in threads.items()), reverse=True)
            memory = target.memory_info()
            row = {'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                   'pid': target.pid, 'cpu_one_core_percent': target.cpu_percent(),
                   'top_threads_percent': [round(v, 1) for v in busiest[:5]],
                   'working_set_mb': round(memory.rss / 1048576, 1),
                   'private_mb': round(getattr(memory, 'private', memory.vms) / 1048576, 1),
                   'thread_count': len(threads), 'system_cpu_percent': psutil.cpu_percent()}
            previous_threads, previous_time = threads, now
            if index % 2 == 0:
                result = subprocess.run(['nvidia-smi', '--query-gpu=utilization.gpu,utilization.memory,memory.used,power.draw,temperature.gpu', '--format=csv,noheader,nounits'], capture_output=True, text=True, timeout=3, creationflags=subprocess.CREATE_NO_WINDOW)
                row['gpu_global'] = result.stdout.strip()
            stream.write(json.dumps(row) + '\n')
            if index % 20 == 0:
                print(json.dumps(row), flush=True)
        except (psutil.NoSuchProcess, psutil.AccessDenied) as error:
            print(type(error).__name__, flush=True)
            break
print('MONITOR_COMPLETE', flush=True)

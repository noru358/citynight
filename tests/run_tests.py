"""Run each Godot test scene headless and isolated. No extra Python packages.
Usage: python3 tests/run_tests.py --godot /path/to/Godot [--output DIR] [--tests RouteProbe ...]
"""
import argparse, os, pathlib, subprocess, sys, tempfile
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--godot', default='godot')
p.add_argument('--output', default=None)
p.add_argument('--tests', nargs='+', default=['DataSuite', 'RouteProbe'])
a = p.parse_args()
project = pathlib.Path(__file__).resolve().parents[1]
out = pathlib.Path(a.output or tempfile.mkdtemp(prefix='citynight-tests-')).resolve()
out.mkdir(parents=True, exist_ok=True)
log = out / 'import.log'
with log.open('w') as f:
    subprocess.run([a.godot, '--headless', '--editor', '--import', '--quit', '--path', str(project)], stdout=f, stderr=subprocess.STDOUT, timeout=180, check=True)
if 'SCRIPT ERROR' in log.read_text():
    sys.exit('script import failed: ' + str(log))
ok = True
for name in a.tests:
    folder = pathlib.Path(tempfile.mkdtemp(prefix=name + '-', dir=out))
    env = dict(os.environ, CITYNIGHT_LOG=str(folder / 'play.jsonl'), CITYNIGHT_TEST_DIR=str(folder))
    result = folder / 'result.log'
    with result.open('w') as f:
        try:
            code = subprocess.run([a.godot, '--headless', '--fixed-fps', '60', '--path', str(project), 'res://tests/%s.tscn' % name], env=env, stdout=f, stderr=subprocess.STDOUT, timeout=300).returncode
        except subprocess.TimeoutExpired:
            code = -1
    text = result.read_text()
    passed = code == 0 and 'SCRIPT ERROR' not in text and 'RESULT' in text
    ok &= passed
    print(name, 'PASS' if passed else 'FAIL')
    for line in text.splitlines():
        if line.startswith(('RESULT', 'ROUTE', 'FAIL', 'ok:', 'SCRIPT ERROR')): print('  ' + line)
sys.exit(0 if ok else 1)

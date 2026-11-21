#!/usr/bin/env python3
"""Opt-in Simulator test using personal grants signed by this Mac's real authority.

Run the normal iOS unit tests first to install the test host. The authority must
already be initialized on this Mac; no key is generated or exported by this tool.
Request/grant tokens stay in the Simulator test container and are removed on exit.
"""
from pathlib import Path
import argparse
import os
import shutil
import subprocess
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--simulator', required=True)
parser.add_argument('--derived-data', type=Path, required=True)
parser.add_argument('--results-dir', type=Path, required=True)
parser.add_argument('--admin-binary', type=Path, required=True)
args = parser.parse_args()
args.results_dir.mkdir(parents=True, exist_ok=True)
directories = set()
stop = threading.Event()
issued = []
errors = []

def approve():
    try:
        deadline = time.monotonic()+240
        while not stop.is_set() and time.monotonic()<deadline:
            container = subprocess.run(['xcrun', 'simctl', 'get_app_container', args.simulator,
                'bewie.atelierindustriel.be', 'data'], capture_output=True, text=True)
            if container.returncode:
                stop.wait(0.25)
                continue
            directory = Path(container.stdout.strip())/'Documents/BlessingIntegration'
            directories.add(directory)
            directory.mkdir(parents=True, exist_ok=True)
            (directory/'enabled').touch()
            for number in [1, 2]:
                request = directory/f'request-{number}.txt'
                grant = directory/f'grant-{number}.txt'
                if request.exists() and not grant.exists() and number not in issued:
                    value = request.read_text().strip()
                    assert value.startswith('https://blessing.bewie.atelierindustriel.be/v1/request/')
                    response = subprocess.run([str(args.admin_binary), 'issue', '--config',
                        str(ROOT/'Bewie/Blessing.public.json'), '--request', value, '--rights', '000'],
                        capture_output=True, text=True)
                    if response.returncode:
                        raise RuntimeError('The Mac could not issue the personal integration grant')
                    temporary = grant.with_suffix('.tmp')
                    with os.fdopen(os.open(temporary, os.O_WRONLY|os.O_CREAT|os.O_TRUNC, 0o600), 'w') as file:
                        file.write(response.stdout.strip())
                    temporary.replace(grant)
                    issued.append(number)
                    print('Mac issued personal 000 integration grant', number, flush=True)
            stop.wait(0.25)
    except Exception as error:
        errors.append(type(error).__name__)

thread = threading.Thread(target=approve)
thread.start()
command = ['xcodebuild', '-project', 'Bewie.xcodeproj', '-scheme', 'Bewie', '-configuration',
    'Debug', '-destination', f'platform=iOS Simulator,id={args.simulator}', '-derivedDataPath',
    str(args.derived_data), '-resultBundlePath', str(args.results_dir/'Blessing.xcresult'),
    '-only-testing:BewieTests/BewieBlessingEndToEndTests', '-jobs', '2',
    'COMPILER_INDEX_STORE_ENABLE=NO', 'test']
log_path = args.results_dir/'blessing-integration.log'
try:
    with os.fdopen(os.open(log_path, os.O_WRONLY|os.O_CREAT|os.O_TRUNC, 0o600), 'w') as log:
        result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
finally:
    stop.set()
    thread.join()
    for directory in directories:
        shutil.rmtree(directory, ignore_errors=True)
assert result.returncode == 0 and issued == [1, 2] and not errors, 'Integration failed; inspect the private log'
print('Mac grants, restoration, idempotent start, stop, replay rejection and fresh approval passed.')

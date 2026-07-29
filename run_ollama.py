#!/usr/bin/env python3
import argparse
import json
import subprocess
from pathlib import Path
import sys

parser = argparse.ArgumentParser(description='Call local ollama model and optionally write+commit output')
parser.add_argument('--model', default='qwen2.5-coder-fast:7b')
parser.add_argument('--prompt', required=True)
parser.add_argument('--out', dest='out_file', default='')
parser.add_argument('--keepalive', type=int, default=5, help='minutes to keep model loaded')
parser.add_argument('--verbose', action='store_true')
parser.add_argument('--apply-git', action='store_true')
parser.add_argument('--commit-message', default='Model-generated update')
args = parser.parse_args()

cmd = ['ollama', 'run', args.model, '--format', 'json', '--keepalive', f'{args.keepalive}m']
if args.verbose:
    cmd.append('--verbose')
cmd += ['--', args.prompt]

try:
    out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True)
except subprocess.CalledProcessError as e:
    print('ollama failed:', e.output, file=sys.stderr)
    sys.exit(1)

try:
    data = json.loads(out)
    message = data.get('message', '')
except json.JSONDecodeError:
    print('Failed to parse ollama JSON output:', out, file=sys.stderr)
    sys.exit(1)

if args.out_file:
    p = Path(args.out_file)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(message, encoding='utf-8')
    print(f'Wrote response to {p}')

    if args.apply_git:
        try:
            subprocess.check_call(['git', 'add', '--', str(p)])
            full_msg = f"{args.commit_message}\n\nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
            subprocess.check_call(['git', 'commit', '-m', full_msg])
            print(f'Committed {p}')
        except subprocess.CalledProcessError:
            print('Git add/commit failed or no changes to commit', file=sys.stderr)
else:
    print(message)

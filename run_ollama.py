#!/usr/bin/env python3
import argparse
import json
import subprocess
from pathlib import Path
import sys

def load_models(repo_root: Path):
    path = repo_root / 'models.json'
    if not path.exists():
        return []
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except Exception:
        return []

repo_root = Path(__file__).parent
models = load_models(repo_root)

parser = argparse.ArgumentParser(description='Call local ollama model and optionally write+commit output')
parser.add_argument('--model', default=None, help='Model id (defaults to first entry in models.json)')
parser.add_argument('--list-models', action='store_true', help='List available models from models.json')
parser.add_argument('--prompt', required=False, help='Prompt to send to the model')
parser.add_argument('--out', dest='out_file', default='')
parser.add_argument('--keepalive', type=int, default=5, help='minutes to keep model loaded')
parser.add_argument('--verbose', action='store_true')
parser.add_argument('--apply-git', action='store_true')
parser.add_argument('--commit-message', default='Model-generated update')
args = parser.parse_args()

if args.list_models:
    if not models:
        print('No models.json found or it is empty')
        sys.exit(1)
    for m in models:
        print(f"{m.get('id')} - {m.get('display_name','')}")
    sys.exit(0)

# Ensure prompt provided when not listing models
if not args.list_models and not args.prompt:
    parser.print_usage()
    print('\nError: --prompt is required unless --list-models is used', file=sys.stderr)
    sys.exit(2)

# Determine model to use
model = args.model
if not model:
    if models:
        model = models[0].get('id')
    else:
        model = 'qwen2.5-coder-fast:7b'

cmd = ['ollama', 'run', model, '--format', 'json', '--keepalive', f'{args.keepalive}m']
if args.verbose:
    cmd.append('--verbose')
cmd += ['--', args.prompt]

try:
    out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace')
except subprocess.CalledProcessError as e:
    print('ollama failed:', e.output, file=sys.stderr)
    sys.exit(1)

try:
    try:
        data = json.loads(out)
    except json.JSONDecodeError:
        # attempt to recover JSON by locating the JSON object near the "message" or "response" key
        import re
        m = re.search(r'(\{[^}]*"(?:message|response)"[^}]*\})', out, re.DOTALL)
        if m:
            candidate = m.group(1)
            data = json.loads(candidate)
        else:
            # fallback: take last '{' and try to parse
            idx = out.rfind('{')
            if idx != -1:
                candidate = out[idx:]
                data = json.loads(candidate)
            else:
                raise
    message = data.get('message', data.get('response', ''))
except Exception:
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

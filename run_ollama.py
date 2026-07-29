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
parser.add_argument('--hide-thinking', dest='hide_thinking', action='store_true', help='Suppress ollama thinking/spinner output (enabled by default)')
parser.add_argument('--no-hide-thinking', dest='hide_thinking', action='store_false', help='Do not suppress ollama thinking output')
parser.set_defaults(hide_thinking=True)
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
if args.hide_thinking:
    cmd.append('--hidethinking')
if args.verbose:
    cmd.append('--verbose')
cmd += ['--', args.prompt]

try:
    out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace')
except subprocess.CalledProcessError as e:
    print('ollama failed:', e.output, file=sys.stderr)
    sys.exit(1)

# Robust JSON extraction: aggressively strip non-printable/spinner chars then locate JSON
import re

# Try direct JSON first
message = None
try:
    data = json.loads(out)
    message = data.get('message', data.get('response', ''))
except Exception:
    # Remove ANSI CSI sequences
    cleaned = re.sub(r'\x1b\[[0-9;]*[A-Za-z]', '', out)
    # Remove braille spinner characters (U+2800–U+28FF)
    cleaned = re.sub(r'[\u2800-\u28FF]', '', cleaned)
    # Remove literal escape sequences like "\u28xx" that some outputs show
    cleaned = re.sub(r'\\u28[0-9a-fA-F]{2}', '', cleaned)
    # Remove other C0 control chars except newline and tab
    cleaned = ''.join(ch for ch in cleaned if ch == '\n' or ch == '\t' or ord(ch) >= 32)
    # Now try to locate the JSON by finding the "message" or "response" token
    for key in ('"message"', '"response"'):
        pos = cleaned.find(key)
        if pos != -1:
            # find nearest '{' before pos and nearest '}' after pos
            open_idx = cleaned.rfind('{', 0, pos)
            close_idx = cleaned.find('}', pos)
            if open_idx != -1 and close_idx != -1 and close_idx > open_idx:
                candidate = cleaned[open_idx:close_idx+1]
                try:
                    data = json.loads(candidate)
                    message = data.get('message', data.get('response', ''))
                    break
                except Exception:
                    pass
    if message is None:
        # fallback: try last '{' to end
        idx = cleaned.rfind('{')
        if idx != -1:
            candidate = cleaned[idx:]
            try:
                data = json.loads(candidate)
                message = data.get('message', data.get('response', ''))
            except Exception:
                pass
    if message is None:
        # final fallback: regex extract of the field value
        m2 = re.search(r'"(?:message|response)"\s*:\s*"([^\"]*)"', cleaned)
        if m2:
            message = m2.group(1)

if message is None:
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

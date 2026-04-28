import urllib.request
import json
import urllib.parse

try:
    symbol = urllib.parse.quote('FX Vol 80')
    url = f'http://localhost:8000/robot/predict_ohlc?symbol={symbol}&horizon=10'
    req = urllib.request.Request(url)
    resp = urllib.request.urlopen(req, timeout=10)
    data = json.loads(resp.read().decode('utf-8'))
    print(f'SUCCESS: {len(data.get("candles", []))} candles returned.')
    print(json.dumps(data["candles"][:2], indent=2))
except Exception as e:
    print(f'ERROR: {e}')

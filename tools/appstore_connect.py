"""Small ASC API client for local tooling; credentials stay outside the checkout."""
import base64
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.error
import urllib.request


class APIError(RuntimeError):
    def __init__(self, status, errors):
        self.status = status
        self.errors = errors
        super().__init__(f'App Store Connect {status}: ' + ' | '.join(x.get('code', '') + ': ' + x.get('detail', x.get('title', '')) for x in errors))


class Client:
    def __init__(self):
        self.values = {}
        path = Path(os.environ.get('ASC_ENV_FILE', str(Path.home()/'.private_keys/appstoreconnect.env')))
        for line in path.read_text().splitlines():
            line = line.strip().removeprefix('export ')
            if '=' in line and not line.startswith('#'):
                key, value = line.split('=', 1)
                self.values[key] = value.strip().strip('"\'')
        self.values.update({k: v for k, v in os.environ.items() if k.startswith('ASC_')})

    def request(self, method, endpoint, body=None):
        assert endpoint.startswith(('/v1/', '/v2/'))
        values = self.values
        encode = lambda data: base64.urlsafe_b64encode(data).rstrip(b'=')
        now = int(time.time())
        header = encode(json.dumps({'alg': 'ES256', 'kid': values['ASC_KEY_ID'], 'typ': 'JWT'}).encode())
        payload = encode(json.dumps({'iss': values['ASC_ISSUER_ID'], 'iat': now, 'exp': now + 1200, 'aud': 'appstoreconnect-v1'}).encode())
        message = header + b'.' + payload
        result = subprocess.run(['/usr/bin/openssl', 'dgst', '-sha256', '-sign', os.path.expanduser(values['ASC_KEY_PATH'])], input=message, capture_output=True)
        if result.returncode:
            raise RuntimeError('Unable to authenticate the App Store Connect request')
        der = result.stdout
        assert der[0] == 48 and der[2] == 2
        count = der[3]
        r = int.from_bytes(der[4:4+count], 'big')
        offset = 4 + count
        assert der[offset] == 2
        s = int.from_bytes(der[offset+2:offset+2+der[offset+1]], 'big')
        token = (message + b'.' + encode(r.to_bytes(32, 'big') + s.to_bytes(32, 'big'))).decode()
        request = urllib.request.Request('https://api.appstoreconnect.apple.com' + endpoint,
            data=json.dumps(body).encode() if body is not None else None,
            headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'}, method=method)
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                data = response.read()
                return json.loads(data) if data else {}
        except urllib.error.HTTPError as error:
            text = error.read().decode()
            for value in [*values.values(), token]:
                if value: text = text.replace(value, '[redacted]')
            raise APIError(error.code, json.loads(text).get('errors', [])) from None

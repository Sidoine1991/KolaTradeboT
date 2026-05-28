"""
Patch SSL global — certificat Windows non reconnu.
Importer en premier dans tout script qui fait des appels HTTPS externes.
"""
import ssl
import urllib3

ssl._create_default_https_context = ssl._create_unverified_context
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

try:
    import requests
    _orig_session_init = requests.Session.__init__
    def _p_session_init(self, *a, **kw):
        _orig_session_init(self, *a, **kw)
        self.verify = False
    requests.Session.__init__ = _p_session_init
except ImportError:
    pass

try:
    import curl_cffi.requests as _cr
    _orig = _cr.Session.__init__
    def _p(self, *a, **kw): kw["verify"] = False; _orig(self, *a, **kw)
    _cr.Session.__init__ = _p
except ImportError:
    pass

try:
    import httpx
    import anthropic
    _orig_a = anthropic.Anthropic.__init__
    def _pa(self, *a, **kw):
        if "http_client" not in kw: kw["http_client"] = httpx.Client(verify=False)
        _orig_a(self, *a, **kw)
    anthropic.Anthropic.__init__ = _pa
except ImportError:
    pass

"""Regression: serving remains healthy after the launcher's stderr disappears."""
from functools import partial
from pathlib import Path
import io
import json
import logging
import sys
import threading
import urllib.request
from serve import ReviewHandler, ReviewServer

root=Path(__file__).resolve().parent
logging.basicConfig(filename=root/'server-regression.log',encoding='utf-8',level=logging.INFO)
server=ReviewServer(('127.0.0.1',0),partial(ReviewHandler,directory=str(root)))
thread=threading.Thread(target=server.serve_forever,daemon=True)
thread.start()
saved_stderr=sys.stderr
closed_console=io.StringIO()
closed_console.close()
paths=['review.html','review-data.js','renders/background.png']
paths.extend('renders/'+path.name for path in (root/'renders').glob('*.webp'))
try:
    sys.stderr=closed_console
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
    for path in paths:
        with opener.open(f'http://127.0.0.1:{server.server_port}/{path}',timeout=5) as response:
            assert response.status==200
            assert response.headers['Cache-Control']=='no-cache'
            assert response.read()==(root/path).read_bytes()
finally:
    sys.stderr=saved_stderr
    server.shutdown()
    server.server_close()
report={'closed_stderr_requests_passed':len(paths),'response_bytes_match':True}
(root/'server_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('SERVER_CLOSED_STDERR_PASS',len(paths))

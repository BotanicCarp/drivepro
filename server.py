from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse
ROOT=Path(__file__).parent.resolve();PORT=5500
class Handler(SimpleHTTPRequestHandler):
 def __init__(self,*a,**k): super().__init__(*a,directory=str(ROOT),**k)
 def do_GET(self):
  p=urlparse(self.path).path
  parts=[x for x in p.split("/") if x]
  if len(parts)==2 and parts[0] in ("i","s"): self.path="/index.html"
  super().do_GET()
print("DrivePro V7: http://localhost:5500")
print("Instructor: http://localhost:5500/i/ivan-petrov")
ThreadingHTTPServer(("127.0.0.1",PORT),Handler).serve_forever()

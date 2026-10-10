from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import argparse
import json
import logging
import os


class ReviewHandler(SimpleHTTPRequestHandler):
    def log_message(self, message, *args):
        # Request logging must not depend on the launching terminal remaining open.
        logging.info('%s %s', self.address_string(), message % args)

    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()


class ReviewServer(ThreadingHTTPServer):
    def handle_error(self, request, client_address):
        logging.exception('Request error from %s', client_address)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=0)
    args=parser.parse_args()
    root=Path(__file__).resolve().parent
    logging.basicConfig(filename=root/'server.log', encoding='utf-8', level=logging.INFO,
                        format='%(asctime)s %(levelname)s %(message)s')
    server=ReviewServer(('127.0.0.1',args.port),partial(ReviewHandler,directory=str(root)))
    url=f'http://127.0.0.1:{server.server_port}/review.html'
    (root/'server.json').write_text(json.dumps({'url':url,'pid':os.getpid()},indent=2),encoding='utf-8')
    logging.info('Serving %s', url)
    try:
        print(url,flush=True)
    except OSError:
        pass
    server.serve_forever()


if __name__=='__main__':
    main()

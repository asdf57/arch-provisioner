"""Loopback-only API fixture for a disposable runner container."""
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path
import sys

sys.path[:0] = [
    '/homelab/ansible-roles/operators',
    '/homelab/ansible-roles/operators/tests'
]
from common import fingerprint
from models import Resource
from runner_credentials import RunnerCredentials
from test_runner_credentials import FixtureAPI


def main() -> None:
    """Serve disposable fixture keys; never contact the real API or log responses."""
    workspace = Path(sys.argv[1])
    credentials = RunnerCredentials((workspace / 'key').read_text(),
                                    (workspace / 'key.pub').read_text(),
                                    (workspace / 'key-cert.pub').read_text())
    api = FixtureAPI(credentials)
    reference = {'name': 'host-key', 'uid': 'host-key-uid'}
    resources: dict[str, Resource] = {
        'inventory-capture-groups/servers': {
            'kind': 'InventoryCaptureGroup',
            'metadata': {
                'name': 'servers',
                'uid': 'group-uid',
                'resourceVersion': '1',
                'generation': 1
            },
            'spec': {},
            'status': {
                'phase': 'Ready',
                'observedGeneration': 1,
                'capturedResources': 1,
                'inventory': {
                    'all': {
                        'hosts': {
                            'fixture': {
                                'ansible_host': '127.0.0.1'
                            }
                        }
                    }
                }
            },
        },
        'servers/fixture': {
            'kind': 'Server',
            'metadata': {
                'name': 'fixture',
                'uid': 'fixture-uid',
                'resourceVersion': '1',
                'generation': 1
            },
            'spec': {},
            'status': {
                'hostSSH': {
                    'phase': 'Ready',
                    'keyReady': True,
                    'keyPairRef': reference,
                    'installedKeyPairRef': reference,
                    'publicKey': credentials.public_key,
                    'fingerprint': fingerprint(credentials.public_key),
                    'installedFingerprint': fingerprint(credentials.public_key)
                }
            },
        },
    }

    class Handler(BaseHTTPRequestHandler):
        """Serve authenticated GETs only; the HTTP server rejects write methods."""

        def do_GET(self) -> None:
            """Reject unauthorized requests before looking up any Secret."""
            token = (workspace / 'token').read_text().strip()
            authorization = self.headers.get('Authorization')
            if authorization not in ('Bearer ' + token,
                                     'Bearer command-test-token'):
                self.send_error(403)
                return
            route = self.path.removeprefix('/api/v1alpha1/')
            # Fleet Commands can read inventory/trust, but never client Secrets.
            if authorization == 'Bearer command-test-token' and route not in resources:
                self.send_error(403)
                return
            if route in resources:
                value = resources[route]
            else:
                try:
                    collection, name = route.split('/', 1)
                    value = api.get(collection, name)
                except (KeyError, ValueError):
                    self.send_error(404)
                    return
            payload = json.dumps(value).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def log_message(self, format: str, *args: str | int) -> None:
            """Keep credential-bearing requests/responses out of fixture output."""

    HTTPServer(('127.0.0.1', 18085), Handler).serve_forever()


if __name__ == '__main__':
    main()

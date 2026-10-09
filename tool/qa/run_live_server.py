#!/usr/bin/env python3
"""Run the real Flutter client/state against a disposable, loopback Django server.

Run with the SERVER's Python environment (Django must be installed).
Never connects to an existing database or deployed server. No credentials are read.
"""
import argparse
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import tempfile
import threading
from datetime import timedelta
from wsgiref.simple_server import make_server


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--server-repo', required=True, type=Path)
    parser.add_argument('--flutter', default='flutter')
    parser.add_argument('--report-dir', required=True, type=Path)
    args = parser.parse_args()
    client = Path(__file__).resolve().parents[2]
    server_repo = args.server_repo.resolve()
    if not (server_repo / 'config/test_settings.py').is_file():
        parser.error('server-repo must contain config/test_settings.py')
    out = args.report_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='wachbuch-live-qa-', dir=os.environ.get('TMPDIR')) as temp:
        sys.path.insert(0, str(server_repo))
        os.environ['DJANGO_SECRET_KEY'] = secrets.token_urlsafe(32)
        os.environ['DJANGO_SETTINGS_MODULE'] = 'config.test_settings'
        import config.test_settings as cfg
        cfg.DATABASES = {'default': {'ENGINE': 'django.db.backends.sqlite3', 'NAME': str(Path(temp) / 'qa.sqlite3')}}
        cfg.ALLOWED_HOSTS = ['127.0.0.1', 'localhost']
        import django
        django.setup()
        from django.core.management import call_command
        from django.core.wsgi import get_wsgi_application
        from django.utils import timezone
        from django.contrib.auth.models import User
        from core.models import Station, Membership, HandoverEntry, ApiToken
        from core.api.views import hash_api_token
        from core.services import update_handover_content
        call_command('migrate', verbosity=0)
        station = Station.objects.create(name='Disposable Client QA', slug='disposable-client-qa')
        user = User.objects.create_user(username='disposable-client-qa')
        member = Membership.objects.create(station=station, user=user, role=Membership.Role.MEMBER)
        entry = HandoverEntry.objects.create(station=station, author=user, title='Neutral Client QA', details='Revision one', category=HandoverEntry.Category.MATERIAL)
        token = 'wb_' + secrets.token_urlsafe(32)
        ApiToken.objects.create(user=user, label='Disposable client QA', token_prefix=token[:11], token_hash=hash_api_token(token), scopes=['read:me', 'read:handovers', 'write:handovers'], expires_at=timezone.now() + timedelta(hours=1))
        app = get_wsgi_application()
        requests = []

        def qa_app(env, start_response):
            def record(status, headers, exc_info=None):
                # No tokens, request bodies, user data or authorization headers.
                requests.append({'method': env['REQUEST_METHOD'], 'path': env['PATH_INFO'], 'status': int(status.split()[0])})
                return start_response(status, headers, exc_info)
            if env['PATH_INFO'] == '/_qa/advance':
                if env['REQUEST_METHOD'] != 'POST' or env.get('HTTP_AUTHORIZATION') != 'Token ' + token:
                    record('403 Forbidden', [('Content-Type', 'application/json')])
                    return [b'{}']
                update_handover_content(entry, {'details': 'Revision two'}, member)
                record('200 OK', [('Content-Type', 'application/json')])
                return [b'{}']
            return app(env, record)

        server = make_server('127.0.0.1', 0, qa_app)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        env = os.environ.copy()
        env.update(WACHBUCH_QA_ORIGIN=f'http://127.0.0.1:{server.server_port}', WACHBUCH_QA_TOKEN=token, WACHBUCH_QA_ID=str(entry.pk))
        try:
            result = subprocess.run([args.flutter, 'test', 'tool/qa/s2_live_server_test.dart', '--reporter', 'expanded', '--no-pub'], cwd=client, env=env, capture_output=True, text=True, timeout=180)
            (out / 'client-network-e2e.log').write_text(result.stdout + '\n' + result.stderr)
            (out / 'client-network-e2e-requests.json').write_text(json.dumps(requests, indent=2) + '\n')
            print(result.stdout, result.stderr)
            print('REAL_CLIENT_HTTP', json.dumps(requests), 'EXIT', result.returncode)
            return result.returncode
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)
            from django.db import connections
            connections.close_all()


if __name__ == '__main__':
    raise SystemExit(main())

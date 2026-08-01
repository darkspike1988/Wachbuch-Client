FROM python:3.13.14-slim-bookworm@sha256:9d7f287598e1a5a978c015ee176d8216435aaf335ed69ac3c38dd1bbb10e8d64

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN groupadd --gid 10001 app && useradd --uid 10001 --gid app --create-home app

COPY requirements.txt .
COPY --chown=app:app manage.py .
COPY --chown=app:app config config
COPY --chown=app:app core core
COPY --chown=app:app scripts scripts
COPY --chown=app:app templates templates

# Install app deps, collect static files, then drop build tooling that is not
# needed at runtime and currently carries fixed HIGH CVEs in the base image
# (setuptools CVE-2025-47273, msgpack GHSA-6v7p-g79w-8964).
RUN pip install --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt \
    && SECRET_KEY=build-only-secret-key-not-used-at-runtime \
       DJANGO_DEBUG=true \
       DATABASE_URL=sqlite:////tmp/rwsth-build.sqlite3 \
       python manage.py collectstatic --noinput \
    && pip uninstall -y pip setuptools wheel msgpack || true \
    && find /usr/local/lib -depth \( \
         -name 'setuptools' -o -name 'setuptools-*' -o -name 'pkg_resources' \
         -o -name 'pip' -o -name 'pip-*' -o -name '_distutils_hack' \
         -o -name 'wheel' -o -name 'wheel-*' \
         -o -name 'msgpack' -o -name 'msgpack-*' \
       \) -exec rm -rf {} +

USER app

EXPOSE 8000

CMD ["/app/scripts/start-web.sh"]

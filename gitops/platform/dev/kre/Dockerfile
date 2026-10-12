FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
# gunicorn cannot import a module name containing hyphens
COPY msef-kre-handler.py kre_handler.py
USER 1000
EXPOSE 8080
# One worker process (the queue and dedup cache are per-process); concurrency
# comes from threads. No --preload: worker threads must start after fork.
# --worker-tmp-dir uses tmpfs because the root filesystem is read-only.
CMD ["gunicorn", "--workers", "1", "--threads", "16", "--bind", "0.0.0.0:8080", \
     "--worker-tmp-dir", "/dev/shm", "--access-logfile", "-", "kre_handler:app"]

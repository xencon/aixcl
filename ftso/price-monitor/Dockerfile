# --- Stage 1: build ---
# build-essential (gcc + libc6-dev + make) required to compile lru-dict (web3 dep).
# Stays in this stage only — never reaches the runtime image.
FROM python:3.12-slim AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# --- Stage 2: runtime ---
# Clean image — no gcc, no build tools, only compiled packages copied from builder.
FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /install /usr/local
COPY monitor.py .
COPY flare_anchor.py .
COPY db.py .

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD wget -qO- http://localhost:9102/metrics | grep -q ftso_poll_total || exit 1

USER nobody

CMD ["python", "-u", "monitor.py"]

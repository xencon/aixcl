FROM python:3.11-slim

RUN groupadd -r ftsoagent --gid=10001 \
 && useradd -r -g ftsoagent --uid=10001 --no-create-home ftsoagent

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY scraper.py classifier.py llm_writer.py agent.py proposer.py ./

# Pre-create /proposals with correct ownership so a named volume
# inherits the image's directory ownership on first mount.
# This avoids rootless UID mapping issues with host bind mounts.
RUN mkdir -p /proposals && chown -R ftsoagent:ftsoagent /proposals

USER ftsoagent

ENTRYPOINT ["python", "-u", "agent.py"]

FROM python:3.11-slim

RUN groupadd -r ftsoagent --gid=10001 \
 && useradd -r -g ftsoagent --uid=10001 --no-create-home ftsoagent

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY scraper.py classifier.py llm_writer.py agent.py ./

USER ftsoagent

ENTRYPOINT ["python", "-u", "agent.py"]

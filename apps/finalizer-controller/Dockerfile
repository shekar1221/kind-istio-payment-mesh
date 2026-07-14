FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY controller.py /app/controller.py

USER 65532:65532
ENTRYPOINT ["python", "/app/controller.py"]

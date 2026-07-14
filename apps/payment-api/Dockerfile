FROM python:3.12-alpine
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN adduser -D -u 10001 appuser
WORKDIR /app
COPY app.py /app/app.py
USER 10001
EXPOSE 8080
ENTRYPOINT ["python", "/app/app.py"]

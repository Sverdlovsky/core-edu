FROM docker.io/library/python:3.12.6-alpine3.19

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src src

RUN addgroup -g 31541 user
RUN adduser -DH -u 31541 -G user user
RUN chown -R user:user .
USER user

EXPOSE 8000

ENTRYPOINT [ "fastapi", "run", "/app/src/App.py", "--port", "8000" ]


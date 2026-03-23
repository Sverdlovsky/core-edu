FROM docker.io/library/python:3.12.6-alpine3.19

WORKDIR /app
COPY . .
RUN pip install --no-cache-dir -r requirements.txt

RUN adduser -DH user
RUN chown -R user:user .
USER user

EXPOSE 8000

ENTRYPOINT [ "fastapi", "run", "App.py", "--port", "8000" ]


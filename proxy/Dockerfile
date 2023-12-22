FROM python:3.11-slim

WORKDIR /app
COPY . /app

RUN pip install --no-cache-dir -r requirements.txt

ENV FLASK_APP=proxy.py
ENV FLASK_RUN_HOST=proxy.py
EXPOSE 5000

CMD [ "python", "-m" , "flask", "run", "--host=0.0.0.0"]
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY msef-kre-handler.py .

EXPOSE 8080

CMD ["python","msef-kre-handler.py"]
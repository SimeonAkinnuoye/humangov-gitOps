FROM public.ecr.aws/docker/library/python:3.8-slim-busterWORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . /app
CMD ["gunicorn", "--workers", "1", "--bind", "0.0.0.0:8000", "humangov:app"]

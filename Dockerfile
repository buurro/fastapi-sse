FROM python:3.10

RUN curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python -

ENV PATH="${PATH}:/root/.poetry/bin"

WORKDIR /app

COPY pyproject.toml .
COPY poetry.lock .
RUN poetry install --no-dev

COPY . .

ENV PYTHONPATH=/app

EXPOSE 80

CMD ["poetry", "run", "uvicorn", "main:app", "--host=0.0.0.0", "--port=80"]

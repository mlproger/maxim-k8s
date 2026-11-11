# 1. Базовый образ
FROM python:3.11-slim

# 2. Метаданные - мейнтейнер образа
LABEL maintainer="fedchenko@lab.local"
LABEL version="1.0"

# 3. Рабочая директория внутри контейнера
WORKDIR /app

# 4. Порт приложения - единое место, дальше используется через ${PORT}
ENV PORT=5487

# 5. Зависимости копируются отдельно от кода,
#    чтобы слой с pip install кэшировался между пересборками
COPY requirements.txt .
RUN pip install -r requirements.txt

# 6. Код приложения
COPY app/ ./app/

# 7. Порт, который слушает приложение
EXPOSE ${PORT}

# 8. Запуск приложения с нашим портом (shell-форма, иначе ${PORT} не подставится)
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT}

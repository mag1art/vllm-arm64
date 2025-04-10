# Используем официальный образ Python 3.12-slim
FROM python:3.12-slim

# Обновляем систему и устанавливаем необходимые пакеты: gcc-12, g++-12, libnuma-dev, git
RUN apt-get update -y && \
    apt-get install -y gcc-12 g++-12 libnuma-dev git && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Обновляем альтернативы для gcc и g++: делаем gcc-12/g++-12 дефолтными
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 10 --slave /usr/bin/g++ g++ /usr/bin/g++-12

# Обновляем pip и устанавливаем инструменты сборки
RUN pip install --upgrade pip && \
    pip install "cmake>=3.26" wheel packaging ninja "setuptools-scm>=8" numpy

# Клонируем репозиторий vLLM
RUN git clone https://github.com/vllm-project/vllm.git /vllm_source

# Клонируем репозиторий Triton и собираем его из исходников
RUN git clone https://github.com/triton-lang/triton.git /triton_source
WORKDIR /triton_source/python
RUN pip install ninja cmake wheel && pip install -e .

# Возвращаемся в директорию с vLLM
WORKDIR /vllm_source

# Удаляем строку с зависимостью triton из requirements, чтобы не возникало конфликта
RUN sed -i '/triton/d' requirements/cpu.txt

# Устанавливаем Python-зависимости для сборки vLLM CPU backend
RUN pip install -v -r requirements/cpu.txt --extra-index-url https://download.pytorch.org/whl/cpu

# Собираем и устанавливаем vLLM для CPU: флаг VLLM_TARGET_DEVICE=cpu задаёт сборку для процессора
RUN VLLM_TARGET_DEVICE=cpu python setup.py install

# Указываем рабочую директорию
WORKDIR /app

ENV MODEL_PATH=/models/deepseek-r1
ENV PORT=5000

# Открываем нужный порт для доступа к сервису
EXPOSE 5000

# Команда для запуска vllm с нужными параметрами
CMD ["sh", "-c", "vllm serve --model $MODEL_PATH --port $PORT"]

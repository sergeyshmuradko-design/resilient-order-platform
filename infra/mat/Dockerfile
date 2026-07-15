# -----------------------------------------------------------------------------
# Eclipse MAT headless image.
#
# MAT 1.17 requires Java 21.
# Этот image используется как одноразовый диагностический инструмент:
# читает heap dump и генерирует HTML/ZIP report.
# -----------------------------------------------------------------------------
FROM eclipse-temurin:21-jdk

# Версия Eclipse Memory Analyzer.
ARG MAT_VERSION=1.17.0

# Дата standalone build.
# Это НЕ полный timestamp archived update site.
ARG MAT_BUILD_DATE=20260601

# Прямая ссылка на официальный standalone Linux archive.
ARG MAT_DOWNLOAD_URL=https://download.eclipse.org/mat/${MAT_VERSION}/rcp/MemoryAnalyzer-${MAT_VERSION}.${MAT_BUILD_DATE}-linux.gtk.x86_64.zip

# curl нужен для скачивания MAT,
# unzip — для распаковки standalone distribution.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl unzip file \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

# Скачиваем напрямую с download.eclipse.org, а не HTML-страницу выбора mirror.
#
# Перед распаковкой:
# 1. выводим тип скачанного файла;
# 2. проверяем ZIP через unzip -t.
#
# Это позволит сразу увидеть понятную ошибку,
# если Eclipse изменит URL или вернёт HTML вместо архива.
RUN curl \
        --fail \
        --location \
        --retry 3 \
        --retry-delay 2 \
        --output mat.zip \
        "${MAT_DOWNLOAD_URL}" \
    && file mat.zip \
    && unzip -t mat.zip \
    && unzip -q mat.zip \
    && rm mat.zip \
    && chmod +x /opt/mat/ParseHeapDump.sh \
    && chmod +x /opt/mat/MemoryAnalyzer

# Аргументы docker compose run будут передаваться ParseHeapDump.sh:
#
# /work/dumps/example.hprof org.eclipse.mat.api:suspects
ENTRYPOINT ["/opt/mat/ParseHeapDump.sh"]
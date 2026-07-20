# 01 System Overview

Первый экран для проверки состояния сервисов.

Основные вопросы:

- доступны ли сервисы;
- растут ли HTTP latency и error rate;
- есть ли давление на CPU, heap, Tomcat или HikariCP;
- увеличиваются ли GC pauses и число потоков.

Фильтры `Service`, `Instance` и `URI` обнаруживаются через Prometheus labels.

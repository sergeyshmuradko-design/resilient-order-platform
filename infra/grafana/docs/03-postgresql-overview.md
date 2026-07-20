# 03 PostgreSQL Overview

## Назначение

Dashboard отвечает на вопрос: **база данных сейчас доступна и не является ли она причиной деградации приложения?**

## Что смотреть сначала

1. `PostgreSQL Availability`
2. `Database Connections`
3. `Transactions per Second`
4. `Rollback Rate`
5. `Buffer Cache Hit Ratio`
6. `Deadlocks`
7. `Locks by Mode`
8. `Temporary Data Written`

## Типичные сценарии

### Растет HTTP latency и количество подключений

Проверьте:

- `Database Connections`;
- Hikari active/pending connections;
- блокировки;
- transaction rate;
- CPU приложения.

### Растет Temporary Data Written

Возможные причины:

- сортировка не помещается в `work_mem`;
- hash join или hash aggregate сбрасывается на диск;
- неэффективный запрос обрабатывает слишком много строк.

### Появились Deadlocks

Нормальное значение — 0. Анализируйте:

- порядок захвата строк и таблиц;
- длительность транзакций;
- параллельные UPDATE/DELETE;
- повторные попытки транзакций на стороне приложения.

## Ограничение

Метрики запросов уровня `pg_stat_statements` по умолчанию в exporter отключены.
Поэтому slow queries и top SQL будут добавлены в PostgreSQL Details после явного
включения расширения и collector.

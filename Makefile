.PHONY: build up stop down ps config load-build load-up load-stop load-down load-config

COMPOSE_LOAD_TEST = docker compose -f docker-compose.yml -f docker-compose.load-test.yml

build:
	docker compose build

up:
	docker compose up -d

stop:
	docker compose stop

down:
	docker compose down

ps:
	docker compose ps

config:
	docker compose config --quiet

load-up:
	$(COMPOSE_LOAD_TEST) up -d grafana order-service

load-build:
	$(COMPOSE_LOAD_TEST) build order-service

load-stop:
	$(COMPOSE_LOAD_TEST) stop

load-down:
	$(COMPOSE_LOAD_TEST) down

load-config:
	$(COMPOSE_LOAD_TEST) config --quiet

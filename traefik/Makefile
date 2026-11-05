up:
	@../scripts/sync.sh

down:
	docker compose down

restart:
	docker compose down && ../scripts/sync.sh

logs:
	docker compose logs -f

composer-install:
	docker compose exec app composer install

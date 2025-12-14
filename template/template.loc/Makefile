up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose down && docker compose up -d

logs:
	docker compose logs -f

composer-install:
	docker compose exec app composer install

artisan:
	docker compose exec app php artisan $(cmd)

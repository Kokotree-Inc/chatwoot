# Variables
APP_NAME := chatwoot
RAILS_ENV ?= development

# Targets
setup:
	gem install bundler
	bundle install
	pnpm install

db_create:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:create

db_migrate:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:migrate

db_seed:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:seed

db_reset:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:reset

db:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails db:chatwoot_prepare

console:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails console

server:
	RAILS_ENV=$(RAILS_ENV) bundle exec rails server -b 0.0.0.0 -p 3000

burn:
	bundle && pnpm install

run:
	@if [ -f ./.overmind.sock ]; then \
		echo "Overmind is already running. Use 'make force_run' to start a new instance."; \
	else \
		overmind start -f Procfile.dev; \
	fi

force_run:
	rm -f ./.overmind.sock
	rm -f tmp/pids/*.pid
	overmind start -f Procfile.dev

force_run_tunnel:
	lsof -ti:3000 | xargs kill -9 2>/dev/null || true
	rm -f ./.overmind.sock
	rm -f tmp/pids/*.pid
	overmind start -f Procfile.tunnel

debug:
	overmind connect backend

debug_worker:
	overmind connect worker

docker: 
	docker build -t $(APP_NAME) -f ./docker/Dockerfile .

docker_up:
	docker compose up -d

docker_down:
	docker compose down

docker_logs:
	docker compose logs -f

docker_restart:
	docker compose restart

docker_rebuild:
	docker compose build

docker_console:
	docker compose exec rails bundle exec rails console

docker_db_prepare:
	docker compose exec rails bundle exec rails db:chatwoot_prepare

docker_db_migrate:
	docker compose exec rails bundle exec rails db:migrate

docker_db_reset:
	docker compose exec rails bundle exec rails db:reset

docker_db_seed:
	docker compose exec rails bundle exec rails db:seed

docker_build_sdk:
	docker compose exec vite pnpm run build:sdk

docker_ps:
	docker compose ps

docker_setup:
	@echo "🔨 Building base image (this may take 5-10 minutes)..."
	docker compose build base
	@echo "🔨 Building all services..."
	docker compose build
	@echo "🗄️  Starting PostgreSQL and Redis..."
	docker compose up -d postgres redis
	@echo "⏳ Waiting for database to be ready (45 seconds)..."
	sleep 45
	@echo "🚀 Starting Vite service (to install node_modules)..."
	docker compose up -d vite
	@echo "⏳ Waiting for node_modules to be installed (30 seconds)..."
	sleep 30
	@echo "🚀 Starting Rails service (needed for database setup)..."
	docker compose up -d rails
	@echo "⏳ Waiting for Rails to be ready (15 seconds)..."
	sleep 15
	@echo "🗄️  Setting up database (this may take a few minutes)..."
	docker compose exec rails bundle exec rails db:chatwoot_prepare
	@echo "📦 Building SDK..."
	docker compose exec vite pnpm run build:sdk
	@echo "🚀 Starting all remaining services..."
	docker compose up -d
	@echo "✅ Setup complete! Access Chatwoot at http://localhost:3100"
	@echo "📧 Login: john@acme.inc / Password1!"

.PHONY: setup db_create db_migrate db_seed db_reset db console server burn docker docker_up docker_down docker_logs docker_restart docker_rebuild docker_console docker_db_prepare docker_db_migrate docker_db_reset docker_db_seed docker_build_sdk docker_ps docker_setup run force_run force_run_tunnel debug debug_worker

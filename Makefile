# Include variables from .env
include .env

# ===================================================================== #
# HELPERS
# ===================================================================== #

## help: print this help message
.PHONY: help
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

.PHONY: confirm
confirm:
	@echo "Are you sure? [y/N]" && read ans && [ $${ans:-N} = y ]

# ===================================================================== #
# DEVELOPMENT
# ===================================================================== #

## run/api: run the cmd/api application
.PHONY: run/api
run/api:
	go run ./cmd/api -db-dsn ${GREENLIGHT_DB_DSN}



## db/psql: connect to the database using psql
.PHONY: db/psql
db/psql:
	psql ${GREENLIGHT_DB_DSN}


## db/migrations/new name=$1: create a new database migration
.PHONY: db/migrations/new
db/migration/new:
	@echo 'Creating migration files for ${name}'
	migrate create -seq -ext=.sql -dir=./migrations ${name}

## db/migrations/up: apply all up database migrations
.PHONY: db/migrations/up
db/migrations/up: confirm
	@echo 'Running up migrations...'
	migrate -path ./migrations -database ${GREENLIGHT_DB_DSN} up

# ===================================================================== #
# QUALITY CONTROL
# ===================================================================== #

## audit: tidy and vendor dependencies and format, vet and test all code
.PHONY: audit
audit: vendor
	@echo 'Formatting code...'
	go fmt ./...
	@echo 'Vetting code...'
	go vet ./...
	@echo 'Running tests...'
	go test -race -vet=off ./...

## vendor:
.PHONY: vendor
vendor:
	@echo 'Tidying and verifying module dependencies'
	go mod tidy
	go mod verify
	@echo 'Vendoring dependencies'
	go mod vendor

# ===================================================================== #
# BUILD
# ===================================================================== #

## build/api: build the cmd/api application
.PHONY: build/api
build/api:
	@echo 'Building cmd/api ...'
	go build -o=./bin/api ./cmd/api
	GOOS=linux GOARCH=amd64 go build -o ./bin/linux_amd64/api ./cmd/api

# ===================================================================== #
# PRODUCTION
# ===================================================================== #

production_host_ip = '143.198.224.115'

## production/connect: connect to the production server
.PHONY: production/connect
production/connect:
	ssh -i ~/.ssh/id_rsa_greenlight greenlight@${production_host_ip}

.PHONY: production/deploy/api
production/deploy/api:
	rsync -e 'ssh -i ~/.ssh/id_rsa_greenlight' -P ./bin/linux_amd64/api greenlight@${production_host_ip}:~
	rsync -e 'ssh -i ~/.ssh/id_rsa_greenlight' -rP --delete ./migrations greenlight@${production_host_ip}:~
	rsync -e 'ssh -i ~/.ssh/id_rsa_greenlight' -P ./remote/production/api.service greenlight@${production_host_ip}:~
	rsync -e 'ssh -i ~/.ssh/id_rsa_greenlight' -P ./remote/production/Caddyfile greenlight@${production_host_ip}:~
	ssh -i ~/.ssh/id_rsa_greenlight -t greenlight@${production_host_ip} '\
		migrate -path ~/migrations -database $$GREENLIGHT_DB_DSN up \
		&& sudo mv ~/api.service /etc/systemd/system/ \
		&& sudo systemctl enable api \
		&& sudo systemctl restart api \
		&& sudo mv ~/Caddyfile /etc/caddy/ \
		&& sudo systemctl reload caddy\
	'
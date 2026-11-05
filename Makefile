.DEFAULT_GOAL := project

## 🚀 Bring certificates, DNS and Traefik in line with DEV_DOMAIN
up:
	@./scripts/sync.sh

## 🌐 Switch this machine to another domain: make domain name=srv.loc
domain:
	@./scripts/set-domain.sh $(name)

project:
	@./scripts/create-project.sh $(name)

## 🔐 Generate local TLS certificates (mkcert)
certs:
	@./scripts/generate-certs.sh

## 🧹 Remove generated certificates
certs-clean:
	@rm -f shared/certs/local.crt shared/certs/local.key
	@echo "🧹 Certificates removed"

# Для macOS
ssh-copy:
	@cat ~/.ssh/id_rsa.pub | pbcopy
	@echo "→ Public key copied to clipboard"

.PHONY: up domain project certs certs-clean ssh-copy

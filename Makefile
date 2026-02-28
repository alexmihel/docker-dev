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
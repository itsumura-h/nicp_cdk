exec:
	docker compose up -d
	docker compose exec app bash

stop:
	docker compose stop

diff:
	git diff --cached >> .diff

reinstall:
	-nimble uninstall nicp_cdk -iy
	nimble install -y

run:
	export TERM=xterm-256color
	nimble uninstall nicp_cdk -iy || true
	nimble install -y
	ndfx cHeaders
	dfx stop || true
	rm -rf /application/examples/*/.dfx
	dfx start --clean --background --host 0.0.0.0:4943 --domain localhost --domain 0.0.0.0

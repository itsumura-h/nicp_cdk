exec:
	docker compose up -d
	docker compose exec app bash

diff:
	git diff --cached >> .diff

reinstall:
	-nimble uninstall nicp_cdk -iy
	nimble install -y

run:
	-nimble uninstall nicp_cdk -iy
	nimble install -y
	ndfx cHeaders
	dfx stop
	rm -rf /application/examples/*/.dfx
	dfx start --clean --background --host 0.0.0.0:4943 --domain localhost --domain 0.0.0.0

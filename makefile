permission:
	local_UID=$(id -u $USER)
	local_GID=$(id -g $USER)
	echo 'start'
	sudo chown ${local_UID}:${local_GID} * -R
	echo '======================'
	sudo find . -name ".*" -print | xargs sudo chown ${local_UID}:${local_GID}
	sudo chown ${local_UID}:${local_GID} .git -R
	echo 'end'

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
	-nimble uninstall nicp_cdk -iy
	nimble install -y
	ndfx cHeaders
	dfx stop
	rm -rf /application/examples/*/.dfx
	dfx start --clean --background --host 0.0.0.0:4943 --domain localhost --domain 0.0.0.0

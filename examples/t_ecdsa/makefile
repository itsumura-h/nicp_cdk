frontend:
	cd src/t_ecdsa_frontend && pnpm dev

backend:
	dfx deploy t_ecdsa_backend -y
	dfx generate t_ecdsa_backend

ii:
	dfx deploy internet_identity -y
	dfx generate internet_identity

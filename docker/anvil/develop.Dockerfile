FROM ghcr.io/foundry-rs/foundry:latest

WORKDIR /anvil

CMD ["anvil", "--host", "0.0.0.0"]

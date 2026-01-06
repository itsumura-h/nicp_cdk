FROM ghcr.io/foundry-rs/foundry:latest

WORKDIR /anvil

ENTRYPOINT ["anvil"]
CMD ["--host", "0.0.0.0", "--port", "8545"]

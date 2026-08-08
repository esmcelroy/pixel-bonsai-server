# Pixel Bonsai Server

Turn a Google Pixel 6 Pro into a private, OpenAI-compatible model server using
[Bonsai](https://huggingface.co/collections/prism-ml/bonsai),
[PrismML's llama.cpp fork](https://github.com/PrismML-Eng/llama.cpp), and
[Termux](https://termux.dev/).

This project borrows the local-first, phone-as-server spirit of
[Pocket Server](https://github.com/yayasoumah/pocket-server) and adapts the
Bonsai/llama-server approach described by
[Dr. StrangeRouter](https://adam-siegel-b.github.io/dr-strangerouter/dr-strangerouter.html)
for a Pixel 6 Pro.

## Why Termux?

Google's Android Linux Terminal VM is not officially available on the Pixel 6
Pro. Termux is therefore the supported path here. It requires neither root nor
an unlocked bootloader.

## Hardware expectations

The Pixel 6 Pro has 12 GB of RAM, but Android and background applications consume
part of it. Start with Bonsai 1.7B and a 4K context. Larger models can fit on disk
but may be slow, thermally constrained, or killed under memory pressure.

| Model | Role on Pixel 6 Pro | Status |
| --- | --- | --- |
| Bonsai 1.7B Q1_0 | Default server and smoke tests | Supported baseline |
| Bonsai 8B Q1_0 | Higher-quality experiments | Experimental |
| Bonsai 27B Q1_0 | Reproducing the desktop guide | Highly experimental |

This repository defaults to CPU inference. The Pixel 6 Pro's Mali GPU does not
make the desktop guide's Metal instructions transferable, and Vulkan support
should be treated as a separate experiment.

## Quick start

Install Termux from F-Droid or the official Termux project source. Avoid mixing
packages from different Termux distribution channels.

In Termux:

```sh
pkg update -y
pkg install -y git
git clone https://github.com/esmcelroy/pixel-bonsai-server.git
cd pixel-bonsai-server
./scripts/bootstrap-termux.sh
./scripts/configure.sh
./scripts/download-model.sh 1.7b
./scripts/start-server.sh
```

The generated `config/server.env` is ignored by Git. `configure.sh` creates a
random 256-bit API key using OpenSSL when available, or Android's
`/dev/urandom` otherwise, and binds the server to the LAN by default. Retrieve
the phone's Wi-Fi address with:

```sh
ip -brief address show wlan0
```

From another machine on the same trusted network:

```sh
curl http://PIXEL_IP:8080/health
curl http://PIXEL_IP:8080/v1/models \
  -H "Authorization: Bearer YOUR_LOCAL_API_KEY"
```

Configure an OpenAI-compatible client with:

- Base URL: `http://PIXEL_IP:8080/v1`
- API key: the value in the phone's ignored `config/server.env`
- Model: `bonsai-1.7b`

### Codex model metadata

Codex uses a richer model catalog than the standard OpenAI `/v1/models`
response returned by llama-server. On the computer running Codex, install the
included catalog into an existing `pixel-bonsai` profile with:

```sh
./scripts/configure-codex.sh pixel-bonsai 16384
```

The second argument must match `CONTEXT_SIZE` on the phone. The helper copies
the catalog to the active Codex configuration directory and sets
`model_catalog_json` in the selected profile. It does not read, copy, or modify
the API key used by that profile.

Do not expose port 8080 directly to the internet. Use a private overlay network
such as Tailscale if access beyond the home LAN is required.

## Commands

```sh
./scripts/start-server.sh             # foreground server
./scripts/healthcheck.sh              # local authenticated check
./scripts/download-model.sh 8b        # optional larger model
./scripts/download-model.sh 27b       # highly experimental
```

Tune `CONTEXT_SIZE`, `THREADS`, and `PARALLEL` in `config/server.env`. Reduce
context size first if Android kills the process or memory allocation fails.

## Operational notes

- Run `termux-wake-lock` before serving to keep the CPU available while the
  phone is unplugged; run `termux-wake-unlock` when finished.
- Expect sustained inference to heat the phone. Remove heavy cases, avoid
  charging at maximum speed during long runs, and stop if Android reports
  thermal warnings.
- Android may suspend Termux. Disable battery optimization for Termux when using
  the phone as a server.
- The model and compiler checkout live below the repository and are ignored by
  Git. No Hugging Face token is needed for the public baseline model.

## Security model

The server refuses a non-loopback bind without an API key. This protects against
accidental unauthenticated LAN exposure, but plain HTTP does not encrypt traffic.
Use only a trusted LAN or an encrypted overlay network. Never reuse a cloud API
key or production credential as the local server key.

## Validation

Desktop validation can check script syntax, but the full acceptance test requires
a physical Pixel 6 Pro:

1. Build the PrismML fork successfully in Termux.
2. Download and load Bonsai 1.7B.
3. Receive a successful `/health` response locally.
4. Complete an authenticated `/v1/chat/completions` request from another LAN host.
5. Record prompt-processing speed, generation speed, peak memory, and temperature.

See [docs/pixel-validation.md](docs/pixel-validation.md) for the test record.

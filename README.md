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
./scripts/start-server.sh interactive
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

### GitHub Copilot CLI

GitHub Copilot CLI supports local OpenAI-compatible providers through BYOK
environment variables. With the Pixel token stored in `~/.pixel_token`, launch
Copilot against the phone with:

```sh
PIXEL_BONSAI_BASE_URL=http://PIXEL_IP:8080/v1 ./scripts/run-copilot.sh
```

The launcher selects the Chat Completions wire API, caps Copilot at a
conservative 4K prompt plus 512 output tokens within the server's 16K window,
marks the API-key environment variable as secret, disables built-in GitHub MCP,
and enables Copilot offline mode. It also removes GitHub authentication variables
from the Copilot child process because offline BYOK does not use them. Override
the defaults without editing the script when necessary:

```sh
PIXEL_BONSAI_BASE_URL=http://PIXEL_IP:8080/v1 \
PIXEL_BONSAI_TOKEN_FILE=/path/to/token \
PIXEL_BONSAI_COPILOT_MAX_PROMPT_TOKENS=4096 \
PIXEL_BONSAI_COPILOT_MAX_OUTPUT_TOKENS=512 \
./scripts/run-copilot.sh
```

Offline mode disables GitHub-hosted features such as delegation and code search.
The Bonsai model meets Copilot CLI's streaming and function-calling requirements,
but its 16K context is substantially below GitHub's recommended 128K minimum.
The smaller Copilot-specific budget is intentional: a full agent request at a
12K prompt budget exceeded the practical latency/stability envelope of the phone.

Do not expose port 8080 directly to the internet. Use a private overlay network
such as Tailscale if access beyond the home LAN is required.

## Commands

```sh
./scripts/start-server.sh interactive     # foreground, 4K context
./scripts/start-server.sh agent           # foreground, 8K context
./scripts/start-server.sh long-context    # foreground, 16K context
./scripts/healthcheck.sh                  # bounded local health check
./scripts/metrics.sh                      # Prometheus-format metrics
./scripts/version-info.sh                 # reproducible build details
./scripts/benchmark.sh                    # CPU/batch benchmark matrix
./scripts/download-model.sh 8b            # optional larger model
./scripts/download-model.sh 27b           # highly experimental
```

## Runtime profiles

Named profiles keep context and batching choices reproducible without copying
credentials or network settings:

| Profile | Context | Intended use | KV cache |
| --- | ---: | --- | --- |
| `interactive` | 4096 | Chat and short requests | F16 |
| `agent` | 8192 | Tool-using coding agents | F16 |
| `long-context` | 16384 | Explicit large-context work | F16 |
| `long-context-q8` | 16384 | Experimental lower-memory 16K work | Q8_0 |

Values in a named profile override tuning values from the ignored
`config/server.env`; host, port, and API key still come from `server.env`.
The Q8 profile must be benchmarked for stability and output quality before
relying on it. Reduce context size first if Android kills the process.

## Benchmarking

Stop the server before benchmarking so two model instances do not compete for
memory, then run:

```sh
sv down pixel-bonsai 2>/dev/null || true
./scripts/benchmark.sh
sv up pixel-bonsai 2>/dev/null || true
```

The default matrix tests 2, 4, and 6 CPU threads; 256 and 512 logical batch
sizes; and 64 and 128 physical micro-batches. Override matrix values through
`BENCHMARK_THREADS`, `BENCHMARK_BATCH_SIZES`, and `BENCHMARK_UBATCH_SIZES`.
Record both prompt-processing and generation throughput because their optimal
settings may differ. See the upstream
[llama-bench documentation](https://github.com/ggml-org/llama.cpp/tree/master/tools/llama-bench)
for output formats and measurement semantics.

## Supervised service

After validating a foreground start, install an automatically restarted Termux
service and health watchdog:

```sh
./scripts/install-service.sh interactive
sv status pixel-bonsai pixel-bonsai-watchdog
```

The service acquires a wake lock when available, counts starts in Termux's
runtime directory, and writes timestamped bounded logs below
`$PREFIX/var/log/`. The watchdog restarts the service after three consecutive
failed health checks. Change the service profile by updating
`$PREFIX/var/service/pixel-bonsai/profile` and restarting the service.
See [termux-services](https://github.com/termux/termux-services) for the runit
service lifecycle and log locations.

Metrics and internal performance timing are enabled by default. `/metrics`
reports throughput, active/deferred requests, and context high-water marks.
Operational endpoints may not require the API key, so expose them only on a
trusted network or private overlay. Metric names and server tuning flags are
documented in the upstream
[llama-server reference](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md).

## Reproducible build

`bootstrap-termux.sh` pins PrismML's llama.cpp fork to commit
`9ca265a57f85f2117942490f421f64a226dd9847`, the revision used by the recorded
physical-device validation. The script refuses to replace a modified vendor
checkout. Run `scripts/version-info.sh` to capture the exact revision, server
build, compiler, architecture, and logical CPU count with benchmark results.

## Operational notes

- The supervised service acquires `termux-wake-lock`; foreground users should
  acquire it manually and run `termux-wake-unlock` when finished.
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

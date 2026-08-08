# Pixel 6 Pro validation record

Record results from the physical device here. Do not include API keys, Wi-Fi
credentials, private addresses, or other secrets.

## Device

- Android version:
- Termux version and source:
- Free storage before model download:
- Battery optimization disabled: yes/no

## Build

- PrismML llama.cpp revision:
- Build result:
- Build duration:

## Inference

Live validation performed on 2026-08-08. The server reported
`n_params=1720028160` (approximately 1.72B parameters) and `n_ctx=16384`.

| Model | Context | Threads | Prompt tokens | Prompt tok/s | Generation tok/s | Wall time | Peak RSS | Notes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Bonsai 1.7B Q1_0 | 16384 | not observed | 25 | 97.66 | 14.47 | 1.23 s | not observed | Warm short request passed and returned `BONSAI_16K_OK`. |
| Bonsai 1.7B Q1_0 | 16384 | not observed | 12024 | 22.31 | 1.74 | 557.53 s | not observed | Large-context request completed with HTTP 200 and 12056 total tokens. Output reached the 32-token limit and did not follow the requested exact response. |

The large-context request used 12,024 prompt tokens rather than filling all
16,384 slots, leaving room for chat templating and generated output. It confirms
large-context prompt processing but is not an exact maximum-capacity test.

## GitHub Copilot CLI compatibility

- OpenAI Chat Completions streaming: passed
- Function calling: passed
- Requested tool call: `ping` with `{"value":"test"}`
- Finish reason: `tool_calls`
- Tool-call test prompt processing: 93.51 tok/s
- Tool-call test generation: 13.80 tok/s
- Copilot CLI context recommendation met: no (16K available; 128K recommended)
- Full Copilot CLI test at a 12,288-token prompt budget: failed after more than
  five minutes with a provider connection error; the server was subsequently
  unreachable
- Conservative Copilot CLI retest: passed at the transport/process level with a
  4,096-token prompt budget and 512-token output budget
- Conservative retest wall time: 721.33 seconds; first streamed output arrived
  after approximately nine minutes
- Conservative retest output: included `COPILOT_PIXEL_OK`, but also emitted
  unexpected datetime and system-reminder markup
- Post-test server health: passed

## Network and security

- Loopback health check passed: not observed from the client; LAN `/health` passed
- Authenticated LAN request passed: yes
- Unauthenticated LAN inference request rejected: yes (`401`)
- Unauthenticated LAN model-list request rejected: no (`/v1/models` returned `200`)
- Internet exposure check passed: yes/no
- Overlay-network test, if used:

## Thermal and stability

- Test duration: 557.53 seconds for the large-context request
- Highest reported battery temperature:
- Android thermal warnings:
- Unexpected process termination:

Client-side Codex validation used a 600,000 ms stream-idle timeout to allow
near-capacity prompt ingestion on the Pixel 6 Pro.

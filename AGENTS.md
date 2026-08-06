# Agent instructions

This repository configures a Google Pixel 6 Pro as a private, OpenAI-compatible
Bonsai model server using Termux and PrismML's llama.cpp fork.

- Never commit model files, tokens, passwords, generated `config/server.env`, or logs.
- Keep the server loopback-only unless authentication is configured explicitly.
- Treat 1.7B as the supported baseline; describe 8B and 27B as experimental until
  benchmarks from a physical Pixel 6 Pro prove otherwise.
- Keep scripts POSIX-compatible where practical and validate them with `shellcheck`.
- Do not add root, bootloader-unlock, or Android system-modification requirements.
- Prefer pinned releases or revisions when a working Pixel build has been verified.


# Changelog

All notable changes to **ModelDesk** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0-phase1] - 2026-09-29

### Added
- **Native Desktop Foundation**: Initialized Flutter Windows desktop application for ModelDesk with dark theme and responsive layout.
- **Process Management Service**: Asynchronous execution of `llama.exe` / `llama-server.exe` with hidden window flags and continuous `stdout`/`stderr` log streaming.
- **Process Tree Cleanup**: Windows `taskkill /F /T` process termination ensuring no orphaned background processes remain on shutdown.
- **Direct Local API Client**: Built-in HTTP client communicating directly with localhost `llama-server` endpoints (`/health` and `/v1/chat/completions`).
- **Native Chat Interface**: Real-time token streaming, thinking/reasoning accordion for reasoning models, live generation metrics ($\text{tokens/sec}$, token count), and smart autoscroll with upward scroll pausing.
- **Stop Generation**: Immediate generation cancellation via client abort token.
- **Conversation Persistence**: Local JSON storage for conversations in `%APPDATA%\LlamaLauncher\chats` with sidebar listing, renaming, and deletion.
- **Startup Session Recovery**: Automatic detection of pre-existing `llama-server` instances on launch to link state without port collisions.
- **Command Preview & Console**: Reactive command preview with 1-click clipboard copy and virtualized ANSI-filtered console viewer.
- **Automated Verification**: End-to-end integration test suite and lifecycle freeze test validating stop mid-generation, app closure, JSON restoration, conversation continuation, server stop/restart, and second chat.

### Known Limitations
- Server configuration parameters and model/mmproj path selection are currently managed via config files and will be fully exposed in the Phase 2 UI.
- Hardware monitoring dashboard (CPU, GPU, VRAM, RAM) is scheduled for Phase 3.

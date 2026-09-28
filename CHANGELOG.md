# Changelog

All notable changes to **ModelDesk** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.3.0-telemetry] - 2026-09-29

### Added
- **Native Dart FFI Telemetry Engine**: 100% native Windows telemetry without Python dependencies or external helper binaries using `dart:ffi`.
- **DirectX DXGI Adapter Query**: Interrogates DXGI COM interfaces (`CreateDXGIFactory`, `EnumAdapters`, `GetDesc`) to discover discrete GPU model names and exact dedicated VRAM capacities.
- **AMD Display Library (ADL) Integration**: Direct C FFI binding with `atiadlxx.dll` via `msvcrt.dll` `malloc`:
  - Real-time 3D GPU engine activity (%).
  - Dedicated VRAM consumption (MB).
  - Multi-point thermal monitoring (Edge, Hotspot/Junction, and Memory temperatures in °C).
  - Live board power consumption (Watts).
  - GPU core (GFX) and memory (MEM) clock frequencies (MHz).
- **Windows System RAM & CPU Monitoring**:
  - Physical RAM total, available, and load percentage via `GlobalMemoryStatusEx`.
  - High-precision delta-based system CPU utilization via `GetSystemTimes`.
- **Process Resource Attribution for `llama-server`**:
  - Tracks the exact working set memory (RAM MB/GB) and CPU utilization of the active `llama-server` child process via `K32GetProcessMemoryInfo` and `GetProcessTimes`.
- **Server Tab Telemetry Dashboard**: 4 rich responsive tiles (CPU, RAM, GPU, Dedicated VRAM) with color-coded progress bars, thermal tags, and board power.
- **Persistent Bottom Hardware Status Bar**: Compact, unobtrusive 32px status strip anchored at the bottom of the window across all tabs (including Chat) with live heartbeat pulse indicator.
- **Phase 3 Test Suite**: Comprehensive tests covering telemetry calculation, FFI execution, polling stream emissions, and controller lifecycle.

## [0.2.0-server] - 2026-09-29

### Added
- **Model Auto-Discovery & Scanning**: Automatic recursive scanning of standard model directories (`~/.lmstudio/models`, `~/models`) and custom user-specified folders for `.gguf` files.
- **Multimodal Projector Separation & Auto-Pairing**: Automatically differentiates LLM weights from multimodal projectors (`mmproj-*.gguf`), pairing matching vision projectors located in the same directory.
- **Native File & Directory Browsers**: Integrated Windows file dialogs (`file_picker`) for selecting `.gguf` models, `mmproj` files, custom model directories, and custom `llama.exe` binaries.
- **Comprehensive Server Parameter Controls**:
  - GPU Layer Offloading (`-ngl`) with quick "All (99)" and "CPU (0)" presets.
  - Context Window Size (`-c`) with standard presets (2K to 128K) and custom entry.
  - CPU inference thread count (`-t`) spinbox.
  - Flash Attention (`-fa`) toggle (on / off).
  - KV Cache Quantization (`-ctk`, `-ctv`) dropdowns (`q8_0`, `q4_0`, `f16`).
  - Parallel Processing Slots (`-np`) control.
  - Network host and port configuration (`--host`, `--port`).
  - Memory locking toggle (`--mlock`) to prevent paging.
  - Custom Extra CLI flags field for advanced arguments.
- **Live Reactive Command Preview**: Real-time preview of the exact `llama-server` CLI invocation with one-click clipboard copy.
- **Two-Column Server Desktop Dashboard**: Clean separation between server controls/configuration and the live ANSI-stripped virtualized console stream.
- **Persistent Configuration**: Auto-saves and restores all server parameters and custom directories across app sessions in `server_config.json`.
- **Phase 2 Test Suite**: Added dedicated tests covering parameter serialization, command building, model scanning, and controller reactivity.

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

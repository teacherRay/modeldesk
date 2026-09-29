# Changelog

All notable changes to **ModelDesk** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-09-29

### Added
- **Developer Benchmark Runner (`MD-Bench 1.0`)**:
  - Hidden developer tool invoked anywhere in ModelDesk using the global shortcut `Ctrl+Shift+B`.
  - Discovers all locally installed GGUF models from the Model Library with selection checkboxes.
  - Fully unattended sequential execution across all selected models with clean server start, readiness verification, execution, shutdown, and config restoration.
  - Complete isolation from standard user chat history, active profiles, and server settings.
  - Guaranteed restoration: original server configuration, model selection, and running state are safely restored in a `finally` block even upon failure or user cancellation.
- **Fixed Benchmark Suite**:
  - Versioned standard configuration: 4096 context, 99 GPU layers, 6 threads, Flash Attention enabled, temperature 0.0.
  - Four standardized evaluation tasks:
    1. *General Knowledge / Prose*: 1,000-word Titanic maiden voyage narrative (for qualitative inspection of factual hallucinations).
    2. *Deterministic Logic / Reasoning*: 4-scientist observation shift scheduling puzzle with unique verifiable answer (`48`).
    3. *Python Coding*: `flatten_and_unique(nested_list)` scored against 5 automated test vectors in an isolated Python runner subprocess.
    4. *Strict Instruction Following*: Space exploration paragraph evaluated across 5 machine-checkable structural constraints.
- **Telemetry & Fingerprinting**:
  - True client-side Time-to-First-Token (TTFT) recorded independently from server request dispatch to first content chunk.
  - Authoritative Prompt Evaluation Time (`prompt_ms`) and prompt tokens/s from llama.cpp server telemetry.
  - Generation speed (`predicted_per_second`), total token counts, and layer offload verification via log scraping.
  - Streaming SHA-256 fingerprinting for GGUF model files with persistent caching at `%APPDATA%\LlamaLauncher\benchmarks\hash_cache.json`.
- **Multi-Format Export Suite**:
  - Pure-Dart multi-sheet Excel workbook (`.xlsx`) generated via Syncfusion with native embedded bar and column charts (Tokens/sec and Quality scores), formatted tables, individual test runs, full raw responses, and host system hardware info.
  - Clean flat CSV export (`.csv`) for data analysis.
  - Structured JSON export (`.json`) for automated pipelines.
  - Dedicated benchmark artifacts folder: `%APPDATA%\LlamaLauncher\benchmarks\MD-Bench_1.0_<timestamp>\`.
- **Unit & Regression Tests**:
  - Comprehensive suite in `test/benchmark_suite_test.dart` verifying constants, SHA-256 cache mechanics, deterministic evaluators (Logic, Python runner, Instruction following), and multi-sheet Excel export.

## [1.0.1] - 2026-09-29

### Changed
- **Default GPU Layers (`-ngl`)**: Increased default GPU offload layers from `18` to `99` across default configuration templates and constructors, ensuring models are fully GPU-offloaded to VRAM by default.
- **Config Schema Migration (v1 → v2)**:
  - Added schema versioning (`config_version: 2`) to `ServerConfig`.
  - Automatic migration detects legacy configurations carrying the old default `nGpuLayers: 18` and transparently upgrades them to `99`.
  - Intentionally customized layer values (e.g. `0` for CPU-only or explicit counts like `42`) are strictly preserved.
  - Migrated configuration is automatically persisted to disk on load.
- **Enhanced llama.cpp Logging (`-lv 4`)**:
  - Automatically appends `-lv 4` to server arguments if not already specified.
  - Exposes detailed llama.cpp initialization diagnostics in the ModelDesk Server Console: Vulkan/ROCm device detection, layer offload breakdown, VRAM allocation, CPU spillover, and KV-cache placement.
- **Authoritative Chat Generation Telemetry**:
  - Chat completions request now specifies `'stream_options': {'include_usage': true}`.
  - Strict separation of prompt prefill from token generation: generation stopwatch starts only upon arrival of the first output token chunk, eliminating TTFT skew.
  - Generation speed (`tokensPerSec`) and token counts now prioritize authoritative `timings.predicted_per_second` and `timings.predicted_n` directly from llama-server's SSE stream instead of approximating from raw SSE message chunks.

### Added
- **Performance Regression Test Suite**: `test/v101_performance_regression_test.dart` validating default layers, config v2 migration rules, `-lv 4` argument injection, and custom argument overrides.

## [1.0.0] - 2026-09-29

### Added
- **Application Settings & Visual Preferences (Phase 5)**:
  - Full-featured **Settings Tab** replacing the final placeholder view.
  - **Multi-Theme Engine**:
    - *Catppuccin Mocha*: Modern slate dark palette with lavender/cyan accents.
    - *Midnight AMOLED*: True pitch-black (`#000000`) high-contrast theme with emerald accents.
    - *Nord Polar Night*: Arctic deep blue-gray palette with frost blue accents.
  - Dynamic real-time theme switching across all views without requiring an application restart.
  - **Hardware Telemetry Preferences**:
    - Adjustable polling interval (1000ms, 1500ms, 3000ms, or Disabled).
    - Toggleable bottom Hardware Status Bar visibility.
  - **Server Automation**:
    - Optional automatic server startup when ModelDesk launches.
  - **Data Maintenance & Safety Operations**:
    - Clear All Conversations routine with interactive confirmation dialog.
    - Reset Server Configuration to known-working defaults with confirmation.
    - Reset Profiles to starter templates with confirmation.
    - 1-click shortcut to open the application data directory (`%APPDATA%\LlamaLauncher`) in Windows Explorer.
- **Publisher & Store Readiness**:
  - Official product branding: **ModelDesk** by **Southern Apps**.
  - Win32 executable metadata (`Runner.rc`) verified with ProductName "ModelDesk" and CompanyName "Southern Apps".
  - Offline privacy guarantee: 100% on-device local execution, zero analytics or telemetry pings.
- **Phase 5 Test Suite**: Added 7 comprehensive unit tests in `test/phase5_settings_and_polish_test.dart` validating AppSettings serialization, multi-theme palettes, SettingsController reactivity, and maintenance operations.

## [0.4.0-profiles] - 2026-09-29

### Added
- **Model Profiles Architecture**:
  - Fine-tuned inference parameter presets capturing GPU layers (`-ngl`), context window (`-c`), CPU threads (`-t`), Flash Attention (`-fa`), KV cache quantization (`-ctk`, `-ctv`), parallel slots (`-np`), host, port, mlock, and extra arguments.
  - Profile persistence in `%APPDATA%\LlamaLauncher\profiles\<id>.json`.
  - Seeded starter templates: *Max GPU Offload (99 Layers)*, *Large Context 32K (KV Quantized)*, and *CPU Fallback (Low VRAM)*.
  - Full profile lifecycle: create, save from active server configuration, duplicate, edit, and delete.
  - 1-click **Apply to Server** and **Apply & Start** controls.
  - Auto-profile lookup matching model file paths or filenames.
- **Dedicated Model Library Tab**:
  - Replaces placeholder view with an interactive, searchable library of all discovered GGUF models.
  - Rich metadata extraction: architecture family badges (Gemma, Qwen, DeepSeek, Llama, etc.), quantization tags (`Q4_K_M`, `Q8_0`, `IQ4_XS`), and parameter sizes (`26B`, `7B`, etc.).
  - Automatic vision projector pairing status badge (`Vision Paired: mmproj-...`).
  - Active server model indicator badge (`ACTIVE IN SERVER`).
  - 1-click actions: **Load in Server**, **Save Profile**, **Show in Explorer**, and **Copy Path**.
  - Dynamic folder search management with chips for each scanned folder and custom directory removal.
- **Dedicated Profiles Management Tab**:
  - Replaces placeholder view with a grid of saved hardware and model presets.
  - Interactive profile creation and editing modal dialogs with sliders and parameter dropdowns.
- **Server Tab Profile Integration**:
  - Direct Profile Quick-Selector dropdown integrated into the Server Tab model selection card.
- **Phase 4 Test Suite**: Added comprehensive tests verifying metadata extraction, ModelProfile serialization roundtrip, and ProfileController operations.

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

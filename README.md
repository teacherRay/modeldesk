# ModelDesk

A modern, native Windows desktop application for running and interacting with local AI models through [llama.cpp](https://github.com/ggml-org/llama.cpp) / `llama-server`.

Developed and published by **Southern Apps**.

---

## 🦙 Overview

**ModelDesk** provides an intuitive, high-performance desktop interface designed specifically for local-first artificial intelligence on Windows. Instead of relying on cloud APIs or embedding full web browsers, ModelDesk acts as a dedicated companion and command center for `llama.cpp`, managing inference as a clean background child process and communicating directly with its native localhost API.

---

## ✨ Features & Architecture

### 1. Native Flutter Chat Interface
- **Direct Local Communication**: Connects directly to the running `llama-server` HTTP API (`/v1/chat/completions`) without an embedded browser.
- **Real-Time Token Streaming**: Streams tokens into assistant responses with sub-millisecond UI updates.
- **Generation Control**: Instant **Send** and **Stop Generation** controls that cleanly abort active HTTP streams.
- **Thinking / Reasoning Support**: Collapsible reasoning accordion for thinking models (such as DeepSeek-R1 and Qwen Coder).
- **Generation Telemetry**: Live performance metrics including tokens per second ($\text{tok/s}$) and total token counts.
- **Smart Autoscroll**: Automatically scrolls down during generation, while allowing the user to freely scroll upward to inspect earlier responses without viewport jumping.

### 2. Local-First JSON Persistence
- **Zero Cloud & Zero Telemetry**: 100% offline and private. Prompts, responses, and conversation histories never leave your machine.
- **Structured Storage**: Conversations are stored locally as clean, portable JSON files with unique IDs, titles, timestamps, and generation stats.
- **Sidebar Management**: Dedicated conversation list with session switching, title editing, and deletion.
- **Corrupted-File Resilience**: Graceful error handling protects existing history if a file is modified externally.

### 3. Server Configuration & Process Control
- **Model Auto-Discovery**: Automatic recursive scanning of standard model directories (`~/.lmstudio/models`, `~/models`) and custom user-specified folders for `.gguf` files.
- **Multimodal Projector Separation & Auto-Pairing**: Distinguishes LLM weights from multimodal projector models (`mmproj-*.gguf`), auto-detecting and pairing matching vision projectors located in the same directory.
- **Native File Dialogs**: Interactive Windows file dialogs to browse `.gguf` models, vision `mmproj` projectors, custom model search folders, and `llama.exe` executable locations.
- **Comprehensive Parameter Tuning**:
  - GPU Layer Offloading (`-ngl`) with quick "All (99)" and "CPU (0)" presets.
  - Context Window Size (`-c`) presets (2K to 128K) and custom input.
  - CPU Inference Threads (`-t`) spinbox control.
  - Flash Attention (`-fa`) toggle (on / off).
  - KV Cache Quantization (`-ctk`, `-ctv`) dropdown selectors (`q8_0`, `q4_0`, `f16`).
  - Parallel Processing Slots (`-np`) control.
  - Host (`--host`) and Port (`--port`) network binding.
  - Memory Locking (`--mlock`) toggle to keep model memory resident.
  - Custom Extra Arguments input field for arbitrary flags.
- **Child Process Management**: Spawns and manages `llama.exe` / `llama-server.exe` as background processes with hidden consoles.
- **Process Tree Cleanup**: Uses Windows process tree termination (`taskkill /F /T`) to prevent orphaned background processes.
- **Live Command Preview**: Real-time display of the exact generated `llama serve` CLI command with 1-click clipboard copying.
- **Virtual Console Stream**: Streams interleaved `stdout`/`stderr` from the inference engine with ANSI stripping and autoscroll controls.

### 4. Real-Time Hardware Telemetry (Zero-Python Native FFI)
- **100% Native Windows Integration**: Pure Dart FFI integration (`dart:ffi`) communicating directly with Windows subsystem DLLs without Python or helper subprocesses.
- **DirectX DXGI VRAM & GPU Discovery**: Enumerates DXGI adapters to identify exact GPU models and dedicated video memory (VRAM) headroom in bytes.
- **AMD Display Library (ADL) Sensors**: Interrogates `atiadlxx.dll` for real-time 3D GPU engine load (%), dedicated VRAM usage (MB), multi-point temperatures (Edge, Hotspot/Junction, Memory in °C), board power (Watts), and core/memory clocks (MHz).
- **System Memory & CPU Load**: Queries `GlobalMemoryStatusEx` and delta-based `GetSystemTimes` for instantaneous CPU % and physical RAM utilization.
- **Inference Process Attribution**: Automatically measures the active `llama-server` process's working set memory and CPU footprint via `K32GetProcessMemoryInfo` and `GetProcessTimes`.
- **Telemetry UI**:
  - **Server Tab Dashboard**: 4 rich tiles displaying CPU, RAM, GPU, and VRAM with Catppuccin theme color thresholds.
  - **Persistent Bottom Status Bar**: Unobtrusive 32px telemetry strip anchored across all tabs with live pulsing heartbeat indicator.

### 5. Model Profiles & Model Library
- **Model Profiles System**:
  - Save, edit, duplicate, and delete fine-tuned inference parameter presets capturing GPU layers (`-ngl`), context window (`-c`), CPU threads (`-t`), Flash Attention (`-fa`), KV cache quantization (`-ctk`, `-ctv`), and parallel slots (`-np`).
  - Stored locally as structured JSON in `%APPDATA%\LlamaLauncher\profiles\<id>.json`.
  - Built-in starter profiles: *Max GPU Offload (99 Layers)*, *Large Context 32K (KV Quantized)*, and *CPU Fallback (Low VRAM)*.
  - 1-click **Apply to Server** and **Apply & Start** controls.
  - Instant Profile Quick-Selector dropdown integrated directly into the Server Tab.
- **Interactive Model Library Tab**:
  - Full-screen catalog of all local GGUF models.
  - Automatic metadata extraction: Architecture family tags (Gemma, Qwen, DeepSeek, Llama, Mistral, Phi, etc.), Quantization tags (`Q4_K_M`, `Q8_0`), and parameter sizes.
  - Multimodal vision projector pairing status badge (`Vision Paired`).
  - Active model indicator badge (`ACTIVE IN SERVER`).
  - Real-time search/filter bar by model name, architecture, or quantization.
  - Quick action buttons on each model card: **Load in Server**, **Save Profile**, **Show in Explorer**, and **Copy Path**.
  - Dynamic folder search management with chips for each scanned folder and custom directory removal.

### 6. Roadmap & Planned Capabilities
- **Phase 1 (Complete)**: Native Flutter desktop app, token streaming, JSON persistence, conversation history.
- **Phase 2 (Complete)**: Full interactive server parameters grid, model auto-discovery, mmproj pairing, native file/folder pickers.
- **Phase 3 (Complete)**: Real-time hardware telemetry dashboard (CPU %, system RAM, DirectX DXGI dedicated VRAM, and AMD ADL die temperatures and board power).
- **Phase 4 (Complete)**: Saved Model Profiles (e.g. *Gemma 4 Vision*, *Qwen Coder*, *Large Context 32K*), Model Library catalog, and auto-profile association.
- **Phase 5**: UI polish, custom themes, and MSIX packaging for Microsoft Store distribution.

---

## 🔒 Privacy & Local Operation

ModelDesk is built strictly around the **local inference philosophy**:
- No user accounts or login required.
- No telemetry, analytics, or background pings.
- No cloud dependencies or third-party tracking.
- All models, prompts, weights, and conversations reside entirely on your personal computer.

---

## 🚀 Current Status

- **Status**: **Phase 4 Complete (Model Profiles & Library)**
- **Milestone**: `v0.4.0-profiles`
- **Supported Platforms**: Windows 10 / 11 (64-bit)

---

## 🛠 Building & Running from Source

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/) (3.24+ recommended)
- [Visual Studio 2022](https://visualstudio.microsoft.com/) with the *Desktop development with C++* workload
- [llama.cpp](https://github.com/ggml-org/llama.cpp) installed (`llama.exe` or `llama-server.exe` in PATH or `%USERPROFILE%\AppData\Local\Microsoft\WindowsApps`)

### Getting Started
```bash
# Clone the repository
git clone https://github.com/teacherRay/modeldesk.git
cd modeldesk

# Fetch dependencies
flutter pub get

# Run static analysis
flutter analyze

# Execute integration tests
flutter test test/integration_phase1_test.dart

# Build Windows Release executable
flutter build windows
```

The compiled standalone executable will be located at:
`build\windows\x64\runner\Release\llama_launcher_flutter.exe` (or double-click `run_app.bat`).

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

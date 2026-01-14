# Dockerization Specification & Analysis

## 1. Overview
The goal is to containerize the build environments for the **Quizzer** application to ensure consistent, reproducible builds across development and CI/CD pipelines.

**Target Build Artifacts:**
- **Android**: APK (`app-release.apk`)
- **Linux**: Portable Executable / Bundle
- **Windows**: Windows Executable (`.exe`)

## 2. Analysis & constraints

### 2.1 Dependencies
The project is a **Flutter** application (`quizzer/`) with potential asset dependencies from the `dataAnalysis` modules (e.g., `.tflite` models).

- **Flutter SDK**: Required for all platforms.
- **Android**: Requires Java/JDK, Android SDK, Android Command Line Tools, Gradle.
- **Linux Desktop**: Requires `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `liblzma-dev`.
- **Windows Desktop**: Requires **Visual Studio Build Tools** (C++ Desktop Development workload).

### 2.2 Docker Limitation - Windows vs. Linux
Docker containers share the kernel of the host operating system.
- **Linux Containers**: Can run on Linux, MacOS (via VM), and Windows (via WSL2/Hyper-V). Ideal for **Linux** and **Android** builds.
- **Windows Containers**: Can **only** run on a Windows host with Hyper-V/Windows Containers feature enabled. They are required to build **Flutter Windows** apps because the MSVC toolchain requires a Windows environment.

**Conclusion**: We cannot use a single Docker image for all three targets. We require a **dual-image strategy**.

### 2.3 Asset Generation Considerations
The `quizzer` application depends on assets in `runtime_cache/models/` and `runtime_cache/subject_data/`.
Currently, `runtime_cache` is **not** ignored in `.gitignore`, implying these assets are version-controlled.
- **Scenario A (Current)**: Assets are present in the repo. The build container only needs Flutter.
- **Scenario B (Auto-generated)**: If these assets are removed from git, the build pipeline must generate them before `flutter build`. This would require the `dataAnalysis` Python scripts to run, necessitating a **Python environment** (with `tensorflow`/`tflite` support) inside the build container or a preceding CI stage.

## 3. Proposed Solution

### 3.1 Image A: `quizzer-builder-linux`
This image acts as the primary build environment for Linux and Android artifacts.

**Base Image**: `ubuntu:22.04` or `debian:bookworm`

**Components**:
1.  **System Deps**: `curl`, `git`, `unzip`, `xz-utils`, `zip`, `libglu1-mesa`.
2.  **Linux Build Chain**: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`.
3.  **Android Toolchain**: 
    -   OpenJDK
    -   Android Command Line Tools
    -   Accepted Licenses
4.  **Flutter SDK**: Installed and configured (stable channel).

**Capabilities**: 
- `flutter build apk`
- `flutter build linux`

### 3.2 Image B: `quizzer-builder-windows`
This image allows for reproducible Windows builds. 
*Note: This image requires a Windows Host to run.*

**Base Image**: `mcr.microsoft.com/windows/servercore:ltsc2022`

**Components**:
1.  **Chocolatey**: Package manager for installation ease.
2.  **Visual Studio Build Tools 2022**: With `Microsoft.VisualStudio.Workload.VCTools`.
3.  **Flutter SDK**: Installed via git or zip.
4.  **Git**: For fetching dependencies (`pub get` often needs git).

**Capabilities**:
- `flutter build windows`

## 4. Implementation Details

### Directory Structure
We will add a `docker/` directory to the root of the repository:
```
/
├── docker/
│   ├── linux/
│   │   └── Dockerfile
│   ├── windows/
│   │   └── Dockerfile
│   └── docker-compose.yml (Optional, mainly for Linux services)
└── ...
```

### Volume Mapping
To build the local source code without copying it permanently into the image:
- **Mount**: The repository root `c:\...\QUIZZER` mapped to `/app` (Linux) or `C:\app` (Windows).
- **Artifacts**: Build outputs (`build/app/outputs/flutter-apk`, `build/linux`, `build/windows`) will be written back to the host filesystem.

### Handling Secrets (Android Signing)
- A key store file (`.jks`) and `key.properties` should NOT be baked into the image.
- They should be injected at runtime via **Docker Secrets** or mapped as a secure volume only during the release build.

## 5. Next Steps
1.  Create `docker/linux/Dockerfile`.
2.  Create `docker/windows/Dockerfile`.
3.  Create build scripts (shell/powershell) to execute the runs uniformly.

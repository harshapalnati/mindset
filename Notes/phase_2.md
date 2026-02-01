# Phase 2: The Native Unit – Onboarding & Local Inference

##  Project Goal
To transition Mindset AI from a cloud-dependent "API Wrapper" into a **Native AI Engine** that runs models locally on the user's hardware with chat UI .

---

##  Architectural Decision: The "Windows Pivot"
During the installation of the **Native Unit**, we encountered a significant environment blocker regarding hardware acceleration on Windows.

### The Conflict: EXLA vs. Windows
* **The Issue**: The `EXLA` (Accelerated Linear Algebra) library lacks precompiled binaries for the `x86_64-windows-cpu` target.
* **The Failure**: Manual compilation via `XLA_BUILD=true` failed due to path length limitations, missing C++ build tools, and `:enoent` errors in the MingW64 environment.
* **The Solution**: We pivoted to the **Pure Elixir/Nx Binary Backend**. 

### Updated Strategy
* **Backend**: Use the standard `Nx` binary backend for tensor operations.
* **Performance**: While slightly slower than XLA, it is stable and requires **zero** complex C++ compilers or Visual Studio installations on the user's machine.
* **Efficiency**: Targeted **1.1B** (TinyLlama) and **2B** (Gemma) parameter models to ensure smooth operation within **16GB of RAM**.



---

##  Implementation Details

### 1. Interactive Setup Wizard (`mix mindset.setup`)
We built a professional-grade onboarding CLI using **Owl** and **Bumblebee**.
* **Hardware Selection**: Provides a clear interface for users to specify their processing unit.
* **Model Management**: A curated list of RAM-friendly models allows the user to choose their preferred "brain".
* **Visual Feedback**: Uses `Owl.Box` for clean layout and `Owl.ProgressBar` to handle the multi-gigabyte download process.

### 2. Dependency Evolution
The `mix.exs` was updated to include the AI heavy-machinery:
* `nx`: Provides the foundation for numerical computing and tensors.
* `bumblebee`: Manages the loading of pre-trained models and conversation logic.
* `owl`: Provides the toolkit for the stylish terminal UI.
* `dotenvy`: Persists local configuration (like model paths and build flags) in a `.env` file.

---

##  Current Blockers & Fixes
| Issue | Cause | Resolution |
| :--- | :--- | :--- |
| `EXLA :enoent` | Missing Windows binaries and failed local C++ build. | Deep cleaned project and switched to Native Nx backend. |
| Environment Persistence | Terminal variables were lost between sessions. | Integrated `.env` via `Dotenvy` for consistent local settings. |
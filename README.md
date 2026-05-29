# VHDL Common

A growing library of reusable VHDL components for digital signal processing and FPGA development. This repository is designed as a central resource where common DSP building blocks can be grabbed and dropped into any project.

---

## Overview

VHDL Common provides synthesisable, well-structured VHDL components that are vendor-agnostic and ready to integrate into a wide range of FPGA projects. The library is actively expanding — contributions and suggestions are welcome.

Current highlights:

- **Open-source floating-point mathematics** — synthesisable IEEE 754 floating-point arithmetic components suitable for FPGA targets
- **Testbenches included** — every component ships with a corresponding testbench under `tb/`


---

## Repository Structure

```
VHDL_Common/
├── src/                  # VHDL source files (synthesisable components)
├── tb/                   # Testbenches for each component
├── requirements.txt      # Python dependencies for simulation tooling
├── setup_venv.py         # Script to set up the Python virtual environment
├── vhdl_ls.toml          # VHDL Language Server configuration
├── .gitattributes
├── .gitignore
└── LICENSE               # MIT License
```

---

## Getting Started

### Prerequisites

- NVC simulator
- GHDL 
- Python 3.x (for simulation scripting)
### Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/Andrew-Thornton/VHDL_Common.git
   cd VHDL_Common
   ```

2. Set up the Python virtual environment for simulation tooling:

   ```bash
   python setup_venv.py
   ```

3. Activate the virtual environment:

   ```bash
   source .venv/bin/activate
   ```

---

## License

This project is licensed under the [MIT License](LICENSE) — free to use, modify, and distribute in any project.

---


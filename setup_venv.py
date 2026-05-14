#!/usr/bin/env python3

import os
import subprocess
import sys
from pathlib import Path

VENV_DIR = ".venv"
REQUIREMENTS = "requirements.txt"


def run(cmd):
    print(f"Running: {' '.join(cmd)}")
    subprocess.check_call(cmd)


def main():
    venv_path = Path(VENV_DIR)

    # Create virtual environment
    if not venv_path.exists():
        print("Creating virtual environment...")
        run([sys.executable, "-m", "venv", VENV_DIR])
    else:
        print("Virtual environment already exists")

    # Determine pip path
    if os.name == "nt":
        pip_path = venv_path / "Scripts" / "pip.exe"
    else:
        pip_path = venv_path / "bin" / "pip"

    # Upgrade pip
    run([str(pip_path), "install", "--upgrade", "pip"])

    # Install requirements
    if Path(REQUIREMENTS).exists():
        run([str(pip_path), "install", "-r", REQUIREMENTS])
    else:
        print("No requirements.txt found")


if __name__ == "__main__":
    main()
# Webkitium macOS / iOS Runner AMI
#
# Builds a macOS AMI (Apple Silicon) with everything needed to compile
# WebKit for both macOS native and iOS Simulator targets.
#
# Usage:
#   packer init macos.pkr.hcl
#   packer build -var 'aws_region=eu-central-1' macos.pkr.hcl
#
# Prerequisites:
#   - An EC2 Mac Dedicated Host allocated in the target region
#   - Xcode .xip pre-uploaded to S3 (or installed on the source AMI)
#
# The resulting AMI can be launched on mac2-m2.metal instances as a
# self-hosted GitHub Actions runner with labels:
#   [self-hosted, macOS, ARM64, webkitium]

packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# ── Variables ────────────────────────────────────────────────────────

variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "instance_type" {
  type    = string
  default = "mac2-m2.metal"
}

variable "volume_size" {
  type    = number
  default = 500
  description = "Root volume in GB. Xcode alone is ~35GB; WebKit build tree ~50GB."
}

variable "ami_prefix" {
  type    = string
  default = "webkitium-macos"
}

variable "source_ami" {
  type    = string
  default = ""
  description = "Base macOS AMI ID. If empty, uses the latest macOS Sequoia AMI from Amazon."
}

variable "xcode_s3_uri" {
  type    = string
  default = ""
  description = "S3 URI to Xcode .xip (e.g. s3://bucket/Xcode_26.3.xip). If empty, assumes Xcode is on the source AMI."
}

variable "github_runner_version" {
  type    = string
  default = "2.333.1"
}

# ── Source AMI ───────────────────────────────────────────────────────

source "amazon-ebs" "macos" {
  region        = var.aws_region
  instance_type = var.instance_type
  ami_name      = "${var.ami_prefix}-{{timestamp}}"

  # Mac Dedicated Host requirement
  tenancy = "host"

  source_ami = var.source_ami != "" ? var.source_ami : null

  # Fallback: find latest macOS AMI if source_ami not specified
  dynamic "source_ami_filter" {
    for_each = var.source_ami == "" ? [1] : []
    content {
      filters = {
        name                = "amzn-ec2-macos-15.*"
        root-device-type    = "ebs"
        virtualization-type = "hvm"
        architecture        = "arm64_mac"
      }
      most_recent = true
      owners      = ["amazon"]
    }
  }

  communicator = "ssh"
  ssh_username = "ec2-user"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = var.volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name    = "${var.ami_prefix}-{{timestamp}}"
    Project = "webkitium"
    Role    = "ci-runner-macos-ios"
  }
}

# ── Build ────────────────────────────────────────────────────────────

build {
  sources = ["source.amazon-ebs.macos"]

  # ── 1. System basics + Xcode license ─────────────────────────────
  provisioner "shell" {
    inline = [
      "set -euo pipefail",

      "# Accept Xcode license (Xcode must be on the source AMI or installed below)",
      "sudo xcodebuild -license accept 2>/dev/null || true",

      "# Ensure Xcode CLT",
      "xcode-select -p || sudo xcode-select --install 2>/dev/null || true",

      "echo 'System basics OK'",
    ]
  }

  # ── 2. Xcode from S3 (optional — skip if source AMI has Xcode) ──
  provisioner "shell" {
    inline = [
      "set -euo pipefail",

      "if [ -z '${var.xcode_s3_uri}' ]; then",
      "  echo 'No Xcode S3 URI — assuming source AMI has Xcode installed'",
      "  xcodebuild -version",
      "  exit 0",
      "fi",

      "echo 'Downloading Xcode from S3...'",
      "aws s3 cp '${var.xcode_s3_uri}' /tmp/Xcode.xip",
      "echo 'Expanding Xcode .xip (this takes ~20 minutes)...'",
      "xip --expand /tmp/Xcode.xip -C /Applications",
      "rm -f /tmp/Xcode.xip",
      "sudo xcode-select -s /Applications/Xcode.app",
      "sudo xcodebuild -license accept",
      "xcodebuild -version",
    ]
  }

  # ── 3. Metal toolchain ───────────────────────────────────────────
  provisioner "shell" {
    inline = [
      "set -euo pipefail",
      "if xcrun --find metal >/dev/null 2>&1; then",
      "  echo 'Metal toolchain already installed'",
      "else",
      "  echo 'Installing Metal toolchain...'",
      "  sudo xcodebuild -downloadComponent MetalToolchain",
      "fi",
      "xcrun --find metal",
    ]
  }

  # ── 4. iOS Simulator runtime ─────────────────────────────────────
  provisioner "shell" {
    inline = [
      "set -euo pipefail",
      "echo 'Checking iOS Simulator runtimes...'",
      "xcrun simctl list runtimes",

      "# If no iOS runtime is available, download one",
      "if ! xcrun simctl list runtimes | grep -q 'iOS'; then",
      "  echo 'No iOS runtime found — downloading latest...'",
      "  sudo xcodebuild -downloadAllPlatforms || {",
      "    echo 'WARNING: Could not download all platforms — iOS sim builds may fail'",
      "  }",
      "fi",
    ]
  }

  # ── 5. Homebrew + build tools ────────────────────────────────────
  provisioner "shell" {
    inline = [
      "set -euo pipefail",

      "# Install Homebrew if missing",
      "if ! command -v brew >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/brew ]; then",
      "  NONINTERACTIVE=1 /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
      "fi",
      "eval \"$(/opt/homebrew/bin/brew shellenv)\"",

      "# Core build dependencies",
      "brew install cmake ninja pkg-config gperf",

      "# Scripting runtimes",
      "brew install python@3.12 ruby",

      "# Git ecosystem",
      "brew install git git-lfs gh",
      "git lfs install",

      "# Optional: sccache for compilation caching",
      "brew install sccache || true",

      "echo 'Homebrew packages installed'",
    ]
  }

  # ── 6. Build directories ─────────────────────────────────────────
  provisioner "shell" {
    inline = [
      "set -euo pipefail",

      "# macOS build source dir",
      "mkdir -p \"$HOME/webkit-src\"",

      "# iOS build source dir (separate to allow parallel builds)",
      "mkdir -p \"$HOME/W/webkit-ios-src\"",

      "# sccache dirs",
      "mkdir -p \"$HOME/webkit-sccache/macos-gh\"",
      "mkdir -p \"$HOME/webkit-sccache/ios-gh\"",

      "echo 'Build directories created'",
    ]
  }

  # ── 7. sudoers for runner (passwordless xcodebuild) ──────────────
  provisioner "shell" {
    inline = [
      "set -euo pipefail",
      "echo 'ec2-user ALL=(root) NOPASSWD: /usr/bin/xcodebuild' | sudo tee /etc/sudoers.d/github-runner-webkitium",
      "sudo chmod 440 /etc/sudoers.d/github-runner-webkitium",
      "echo 'sudoers configured'",
    ]
  }

  # ── 8. GitHub Actions runner ─────────────────────────────────────
  provisioner "shell" {
    inline = [
      "set -euo pipefail",
      "mkdir -p \"$HOME/actions-runner\"",
      "cd \"$HOME/actions-runner\"",
      "curl -sL -o runner.tar.gz \"https://github.com/actions/runner/releases/download/v${var.github_runner_version}/actions-runner-osx-arm64-${var.github_runner_version}.tar.gz\"",
      "tar -xzf runner.tar.gz",
      "rm runner.tar.gz",
      "echo 'GitHub Actions runner extracted (configure with ./config.sh after launch)'",
    ]
  }

  # ── 9. Shell profile for CI ──────────────────────────────────────
  provisioner "shell" {
    inline = [
      "set -euo pipefail",

      "# Ensure Homebrew + tools are on PATH for non-login shells (GitHub Actions)",
      "cat >> \"$HOME/.bashrc\" << 'PROFILE'",
      "eval \"$(/opt/homebrew/bin/brew shellenv)\"",
      "export PATH=\"/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH\"",
      "PROFILE",

      "# Same for zsh",
      "cat >> \"$HOME/.zshrc\" << 'PROFILE'",
      "eval \"$(/opt/homebrew/bin/brew shellenv)\"",
      "export PATH=\"/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH\"",
      "PROFILE",

      "echo 'Shell profile configured'",
    ]
  }

  # ── 10. Validation ──────────────────────────────────────────────
  provisioner "shell" {
    inline = [
      "set -euo pipefail",
      "eval \"$(/opt/homebrew/bin/brew shellenv)\"",

      "echo '=== macOS/iOS Runner Validation ==='",
      "echo ''",

      "fail=false",

      "for cmd in git gh cmake ninja python3 ruby perl xcodebuild xcrun; do",
      "  if command -v $cmd >/dev/null 2>&1; then",
      "    echo \"  OK    $cmd  ($(command -v $cmd))\"",
      "  else",
      "    echo \"  MISS  $cmd\"",
      "    fail=true",
      "  fi",
      "done",

      "# Metal toolchain",
      "if xcrun --find metal >/dev/null 2>&1; then",
      "  echo '  OK    metal'",
      "else",
      "  echo '  MISS  metal (Metal toolchain not installed)'",
      "  fail=true",
      "fi",

      "# iOS Simulator",
      "if xcrun simctl list runtimes | grep -q 'iOS'; then",
      "  echo '  OK    iOS Simulator runtime'",
      "else",
      "  echo '  WARN  no iOS Simulator runtime (iOS builds will fail)'",
      "fi",

      "# Disk",
      "free_gb=$(df -g / | tail -1 | awk '{print $4}')",
      "echo \"  OK    ${free_gb}GB free on /\"",

      "echo ''",
      "if $fail; then",
      "  echo 'VALIDATION FAILED'",
      "  exit 1",
      "fi",
      "echo 'All tools validated.'",
    ]
  }
}

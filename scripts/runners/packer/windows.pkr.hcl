# Webkitium Windows Runner AMI
#
# Builds a Windows Server 2022 AMI with everything needed to compile
# WebKit (WebGPU/Dawn + WebNN) and build the native browser shell.
#
# Usage:
#   packer init windows.pkr.hcl
#   packer build -var 'aws_region=eu-west-1' windows.pkr.hcl
#
# The resulting AMI can be launched as a self-hosted GitHub Actions
# runner with labels: [self-hosted, Windows, X64, webkitium]

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
  default = "eu-west-1"
}

variable "instance_type" {
  type    = string
  default = "c5.4xlarge"
}

variable "volume_size" {
  type    = number
  default = 2048
  description = "Root volume size in GB. WebKit + vcpkg + sccache need ~500GB; 2TB gives headroom."
}

variable "ami_prefix" {
  type    = string
  default = "webkitium-windows"
}

# ── Tool versions (bump these when upgrading) ────────────────────────

variable "llvm_version" {
  type    = string
  default = "19.1.0"
}

variable "cmake_version" {
  type    = string
  default = "4.3.1"
}

variable "python_version" {
  type    = string
  default = "3.14.0"
}

variable "ruby_version" {
  type    = string
  default = "3.4.9-1"
}

variable "strawberry_perl_version" {
  type    = string
  default = "5.42.2.1"
}

variable "git_version" {
  type    = string
  default = "2.53.0"
}

variable "gh_cli_version" {
  type    = string
  default = "2.73.0"
}

variable "sccache_version" {
  type    = string
  default = "0.10.0"
}

variable "vcpkg_baseline" {
  type    = string
  default = "17e4940625388c7b893b6f3cb0bff43977da5a5f"
  description = "Must match config/webkit-build-matrix.json -> dawn.vcpkgBaseline"
}

variable "github_runner_version" {
  type    = string
  default = "2.333.1"
}

# ── Source AMI ───────────────────────────────────────────────────────

source "amazon-ebs" "windows" {
  region        = var.aws_region
  instance_type = var.instance_type
  ami_name      = "${var.ami_prefix}-{{timestamp}}"

  source_ami_filter {
    filters = {
      name                = "Windows_Server-2022-English-Full-Base-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }

  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_insecure = true
  winrm_use_ssl  = true

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = var.volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name    = "${var.ami_prefix}-{{timestamp}}"
    Project = "webkitium"
    Role    = "ci-runner-windows"
  }
}

# ── Build ────────────────────────────────────────────────────────────

build {
  sources = ["source.amazon-ebs.windows"]

  # ── 1. Visual Studio Build Tools + Desktop C++ workload ──────────
  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",

      "# Download VS Build Tools bootstrapper",
      "$bsUrl = 'https://aka.ms/vs/18/release/vs_BuildTools.exe'",
      "$bsPath = 'C:\\Bootstrap\\installers\\vs_BuildTools.exe'",
      "New-Item -Path C:\\Bootstrap\\installers -ItemType Directory -Force | Out-Null",
      "Invoke-WebRequest -Uri $bsUrl -OutFile $bsPath -UseBasicParsing",

      "# Install Desktop C++ workload with MSVC, ATL, ASAN, Win SDK",
      "Start-Process -Wait -FilePath $bsPath -ArgumentList @(",
      "  '--quiet', '--wait', '--norestart',",
      "  '--installPath', 'C:\\BuildTools',",
      "  '--add', 'Microsoft.VisualStudio.Workload.VCTools',",
      "  '--add', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',",
      "  '--add', 'Microsoft.VisualStudio.Component.VC.ATL',",
      "  '--add', 'Microsoft.VisualStudio.Component.VC.ASAN',",
      "  '--add', 'Microsoft.VisualStudio.Component.Windows11SDK.26100',",
      "  '--add', 'Microsoft.VisualStudio.Component.Windows11SDK.22621',",
      "  '--add', 'Microsoft.VisualStudio.Component.VC.CMake.Project',",
      "  '--add', 'Microsoft.Component.MSBuild',",
      "  '--add', 'Microsoft.NetCore.Component.SDK'",
      ")",

      "Write-Host 'Visual Studio Build Tools installed'",
    ]
  }

  # ── 2. LLVM / Clang toolchain ────────────────────────────────────
  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "$url = \"https://github.com/niccokunzmann/niccokunzmann.github.io/releases/download/llvmorg-${var.llvm_version}/LLVM-${var.llvm_version}-win64.exe\"",
      "$out = 'C:\\Bootstrap\\installers\\llvm.exe'",
      "Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing",
      "Start-Process -Wait -FilePath $out -ArgumentList '/S', '/D=C:\\Program Files\\LLVM'",
      "Write-Host 'LLVM installed'",
    ]
  }

  # ── 3. Git + Git LFS + GitHub CLI ────────────────────────────────
  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",

      "# Git",
      "$gitUrl = \"https://github.com/niccokunzmann/niccokunzmann.github.io/releases/download/v${var.git_version}.windows.1/Git-${var.git_version}-64-bit.exe\"",
      "$gitOut = 'C:\\Bootstrap\\installers\\git.exe'",
      "Invoke-WebRequest -Uri $gitUrl -OutFile $gitOut -UseBasicParsing",
      "Start-Process -Wait -FilePath $gitOut -ArgumentList '/VERYSILENT', '/NORESTART', '/DIR=C:\\Program Files\\Git'",

      "# GitHub CLI",
      "$ghUrl = \"https://github.com/cli/cli/releases/download/v${var.gh_cli_version}/gh_${var.gh_cli_version}_windows_amd64.msi\"",
      "$ghOut = 'C:\\Bootstrap\\installers\\gh.msi'",
      "Invoke-WebRequest -Uri $ghUrl -OutFile $ghOut -UseBasicParsing",
      "Start-Process -Wait msiexec.exe -ArgumentList '/i', $ghOut, '/quiet', '/norestart'",

      "# Git LFS",
      "& 'C:\\Program Files\\Git\\cmd\\git.exe' lfs install",

      "Write-Host 'Git + gh + LFS installed'",
    ]
  }

  # ── 4. Scripting runtimes (Python, Ruby, Perl) ───────────────────
  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",

      "# Python",
      "$pyUrl = \"https://www.python.org/ftp/python/${var.python_version}/python-${var.python_version}-amd64.exe\"",
      "Invoke-WebRequest -Uri $pyUrl -OutFile C:\\Bootstrap\\installers\\python.exe -UseBasicParsing",
      "Start-Process -Wait C:\\Bootstrap\\installers\\python.exe -ArgumentList '/quiet', 'InstallAllUsers=1', 'TargetDir=C:\\Python314', 'PrependPath=1'",

      "# Ruby",
      "$rubyUrl = \"https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-${var.ruby_version}/rubyinstaller-${var.ruby_version}-x64.exe\"",
      "Invoke-WebRequest -Uri $rubyUrl -OutFile C:\\Bootstrap\\installers\\ruby.exe -UseBasicParsing",
      "Start-Process -Wait C:\\Bootstrap\\installers\\ruby.exe -ArgumentList '/verysilent', '/dir=C:\\Ruby34-x64'",

      "# Strawberry Perl",
      "$perlUrl = \"https://github.com/niccokunzmann/niccokunzmann.github.io/releases/download/Strawberry-perl-${var.strawberry_perl_version}/strawberry-perl-${var.strawberry_perl_version}-64bit.msi\"",
      "Invoke-WebRequest -Uri $perlUrl -OutFile C:\\Bootstrap\\installers\\perl.msi -UseBasicParsing",
      "Start-Process -Wait msiexec.exe -ArgumentList '/i', 'C:\\Bootstrap\\installers\\perl.msi', '/quiet', '/norestart', 'INSTALLDIR=C:\\Strawberry'",

      "Write-Host 'Python, Ruby, Perl installed'",
    ]
  }

  # ── 5. CMake (standalone, not just VS-integrated) ────────────────
  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "$cmakeUrl = \"https://github.com/Kitware/CMake/releases/download/v${var.cmake_version}/cmake-${var.cmake_version}-windows-x86_64.msi\"",
      "Invoke-WebRequest -Uri $cmakeUrl -OutFile C:\\Bootstrap\\installers\\cmake.msi -UseBasicParsing",
      "Start-Process -Wait msiexec.exe -ArgumentList '/i', 'C:\\Bootstrap\\installers\\cmake.msi', '/quiet', '/norestart'",
      "Write-Host 'CMake installed'",
    ]
  }

  # ── 6. vcpkg ─────────────────────────────────────────────────────
  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "& 'C:\\Program Files\\Git\\cmd\\git.exe' clone https://github.com/microsoft/vcpkg.git C:\\vcpkg",
      "Set-Location C:\\vcpkg",
      "& 'C:\\Program Files\\Git\\cmd\\git.exe' checkout ${var.vcpkg_baseline}",
      ".\\bootstrap-vcpkg.bat -disableMetrics",
      "[Environment]::SetEnvironmentVariable('VCPKG_ROOT', 'C:\\vcpkg', 'Machine')",
      "New-Item -Path C:\\vcpkg\\buildtrees -ItemType Directory -Force | Out-Null",
      "New-Item -Path C:\\vcpkg\\installed -ItemType Directory -Force | Out-Null",
      "New-Item -Path C:\\vcpkg\\packages -ItemType Directory -Force | Out-Null",
      "New-Item -Path C:\\vcpkg\\downloads -ItemType Directory -Force | Out-Null",
      "New-Item -Path C:\\vcpkg\\archives -ItemType Directory -Force | Out-Null",
      "Write-Host 'vcpkg installed at baseline ${var.vcpkg_baseline}'",
    ]
  }

  # ── 7. sccache ───────────────────────────────────────────────────
  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "New-Item -Path C:\\Bootstrap\\toolbin -ItemType Directory -Force | Out-Null",
      "$url = \"https://github.com/niccokunzmann/niccokunzmann.github.io/releases/download/v${var.sccache_version}/sccache-v${var.sccache_version}-x86_64-pc-windows-msvc.tar.gz\"",
      "Invoke-WebRequest -Uri $url -OutFile C:\\Bootstrap\\installers\\sccache.tar.gz -UseBasicParsing",
      "tar -xzf C:\\Bootstrap\\installers\\sccache.tar.gz -C C:\\Bootstrap\\toolbin --strip-components=1 sccache-v${var.sccache_version}-x86_64-pc-windows-msvc/sccache.exe",
      "New-Item -Path C:\\Bootstrap\\sccache-gh\\windows-webgpu-dawn -ItemType Directory -Force | Out-Null",
      "Write-Host 'sccache installed'",
    ]
  }

  # ── 8. PowerShell 7 ──────────────────────────────────────────────
  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "if (-not (Test-Path 'C:\\Program Files\\PowerShell\\7\\pwsh.exe')) {",
      "  $url = 'https://github.com/PowerShell/PowerShell/releases/download/v7.6.4/PowerShell-7.6.4-win-x64.msi'",
      "  Invoke-WebRequest -Uri $url -OutFile C:\\Bootstrap\\installers\\pwsh.msi -UseBasicParsing",
      "  Start-Process -Wait msiexec.exe -ArgumentList '/i', 'C:\\Bootstrap\\installers\\pwsh.msi', '/quiet', '/norestart'",
      "}",
      "Write-Host 'PowerShell 7 installed'",
    ]
  }

  # ── 9. protobuf (for WebNN / LiteRT-LM) ─────────────────────────
  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "& 'C:\\Program Files\\Git\\cmd\\git.exe' clone --depth 1 --branch v0.10.2 https://github.com/google-ai-edge/LiteRT-LM.git C:\\Bootstrap\\litert-lm",
      "Set-Location C:\\Bootstrap\\litert-lm",
      "& 'C:\\Program Files\\Git\\cmd\\git.exe' lfs pull --include='prebuilt/windows_x86_64/*'",
      "Write-Host \"LiteRT-LM DLLs: $((Get-ChildItem C:\\Bootstrap\\litert-lm\\prebuilt\\windows_x86_64\\*.dll).Count)\"",
    ]
  }

  # ── 10. Build directories + PATH ─────────────────────────────────
  provisioner "powershell" {
    inline = [
      "New-Item -Path C:\\W -ItemType Directory -Force | Out-Null",

      "# Set system PATH for the runner",
      "$additions = @(",
      "  'C:\\Bootstrap\\toolbin',",
      "  'C:\\Program Files\\Git\\cmd',",
      "  'C:\\Ruby34-x64\\bin',",
      "  'C:\\Python314',",
      "  'C:\\Python314\\Scripts',",
      "  'C:\\Program Files\\LLVM\\bin',",
      "  'C:\\Program Files\\CMake\\bin',",
      "  'C:\\Strawberry\\perl\\bin',",
      "  'C:\\Program Files\\GitHub CLI'",
      ")",
      "$currentPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')",
      "foreach ($p in $additions) {",
      "  if ($currentPath -notlike \"*$p*\") { $currentPath = \"$p;$currentPath\" }",
      "}",
      "[Environment]::SetEnvironmentVariable('Path', $currentPath, 'Machine')",
      "Write-Host 'System PATH updated'",
    ]
  }

  # ── 11. GitHub Actions runner ────────────────────────────────────
  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "New-Item -Path C:\\actions-runner -ItemType Directory -Force | Out-Null",
      "$url = \"https://github.com/actions/runner/releases/download/v${var.github_runner_version}/actions-runner-win-x64-${var.github_runner_version}.zip\"",
      "Invoke-WebRequest -Uri $url -OutFile C:\\actions-runner\\runner.zip -UseBasicParsing",
      "Expand-Archive -Path C:\\actions-runner\\runner.zip -DestinationPath C:\\actions-runner -Force",
      "Remove-Item C:\\actions-runner\\runner.zip",
      "Write-Host 'GitHub Actions runner extracted (configure with ./config.cmd after launch)'",
    ]
  }

  # ── 12. Cleanup installers to reduce AMI size ────────────────────
  provisioner "powershell" {
    inline = [
      "Remove-Item -Recurse -Force C:\\Bootstrap\\installers -ErrorAction SilentlyContinue",
      "Write-Host 'Installers cleaned up'",
    ]
  }

  # ── 13. Validation ───────────────────────────────────────────────
  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Continue'",
      "$fail = $false",
      "$checks = @{",
      "  'VsDevCmd'  = 'C:\\BuildTools\\Common7\\Tools\\VsDevCmd.bat'",
      "  'clang-cl'  = 'C:\\Program Files\\LLVM\\bin\\clang-cl.exe'",
      "  'lld-link'  = 'C:\\Program Files\\LLVM\\bin\\lld-link.exe'",
      "  'cmake'     = 'C:\\Program Files\\CMake\\bin\\cmake.exe'",
      "  'git'       = 'C:\\Program Files\\Git\\cmd\\git.exe'",
      "  'gh'        = 'C:\\Program Files\\GitHub CLI\\gh.exe'",
      "  'python'    = 'C:\\Python314\\python.exe'",
      "  'ruby'      = 'C:\\Ruby34-x64\\bin\\ruby.exe'",
      "  'perl'      = 'C:\\Strawberry\\perl\\bin\\perl.exe'",
      "  'sccache'   = 'C:\\Bootstrap\\toolbin\\sccache.exe'",
      "  'vcpkg'     = 'C:\\vcpkg\\vcpkg.exe'",
      "  'pwsh'      = 'C:\\Program Files\\PowerShell\\7\\pwsh.exe'",
      "}",
      "foreach ($k in $checks.Keys | Sort-Object) {",
      "  if (Test-Path $checks[$k]) { Write-Host \"  OK    $k\" }",
      "  else { Write-Host \"  MISS  $k  ($($checks[$k]))\"; $fail = $true }",
      "}",
      "if ($fail) { throw 'Validation failed — see MISS entries above' }",
      "Write-Host 'All tools validated.'",
    ]
  }
}

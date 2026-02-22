#!/bin/bash
set -e

# =============================================================
# EC2 Gemini CLI Sandbox Setup Script
# 대상: Ubuntu 20.04 ~ 24.04 (x86_64 / aarch64)
# 참고: https://github.com/google-gemini/gemini-cli
# =============================================================

ARCH=$(uname -m)
OS=$(uname -s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== EC2 Gemini CLI Setup ==="
echo "OS: $OS | ARCH: $ARCH"
echo ""

# -------------------------------------------------------------
# [0] .env 파일 로드 (GEMINI_API_KEY 등)
# -------------------------------------------------------------
if [ -f "$SCRIPT_DIR/.env" ]; then
    echo "[0] Loading .env..."
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
    echo "  [OK] .env loaded"
elif [ -f "$HOME/.env" ]; then
    echo "[0] Loading ~/.env..."
    set -a
    source "$HOME/.env"
    set +a
    echo "  [OK] ~/.env loaded"
else
    echo "[0] No .env found — GEMINI_API_KEY must be set manually after install"
fi

# -------------------------------------------------------------
# [1] 스왑 메모리 설정 (16GB) - 중복 방지
# -------------------------------------------------------------
echo ""
echo "[1] Setting up swap..."
if [ -f /swapfile ]; then
    echo "  [SKIP] /swapfile already exists"
else
    sudo fallocate -l 16G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "  [OK] 16G swap created"
fi
swapon --show

# -------------------------------------------------------------
# [2] cokacdir 설치 (디렉토리 이동 개선 도구)
# -------------------------------------------------------------
echo ""
echo "[2] Installing cokacdir..."
if command -v cokacdir &>/dev/null; then
    echo "  [SKIP] cokacdir already installed"
else
    /bin/bash -c "$(curl -fsSL https://cokacdir.cokac.com/install.sh)"
    echo "  [OK] cokacdir installed"
fi

# -------------------------------------------------------------
# [3] NVM + Node.js 24 설치
# -------------------------------------------------------------
echo ""
echo "[3] Installing NVM + Node.js 24..."
if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    echo "  [OK] NVM installed"
else
    echo "  [SKIP] NVM already installed"
fi

# 현재 쉘에서 NVM 즉시 활성화 (source ~/.bashrc는 서브쉘에서 불가)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if ! node -v 2>/dev/null | grep -q "v2[4-9]"; then
    nvm install 24
    nvm use 24
    echo "  [OK] Node.js $(node -v) installed"
else
    echo "  [SKIP] Node.js $(node -v) already installed"
fi

# -------------------------------------------------------------
# [4] Gemini CLI 설치
# -------------------------------------------------------------
echo ""
echo "[4] Installing Gemini CLI..."
if command -v gemini &>/dev/null; then
    echo "  [SKIP] Gemini CLI already installed: $(gemini --version 2>/dev/null || echo 'version unknown')"
else
    npm install -g @google/gemini-cli
    echo "  [OK] Gemini CLI installed"
fi

# -------------------------------------------------------------
# [5] GEMINI_API_KEY 환경변수 설정 (.bashrc에 영구 등록)
# -------------------------------------------------------------
echo ""
echo "[5] Configuring GEMINI_API_KEY..."
if [ -n "$GEMINI_API_KEY" ]; then
    # 이미 .bashrc에 등록되어 있는지 확인
    if ! grep -q "GEMINI_API_KEY" "$HOME/.bashrc"; then
        echo "export GEMINI_API_KEY=\"$GEMINI_API_KEY\"" >> "$HOME/.bashrc"
        echo "  [OK] GEMINI_API_KEY added to ~/.bashrc"
    else
        echo "  [SKIP] GEMINI_API_KEY already in ~/.bashrc"
    fi
else
    echo "  [WARN] GEMINI_API_KEY not set — add to ~/.bashrc manually:"
    echo "         export GEMINI_API_KEY=\"your_key_here\""
fi

# -------------------------------------------------------------
# [6] Playwright 자동 설치 (MCP 서버용)
# -------------------------------------------------------------
echo ""
echo "=== Playwright Auto Install ==="
echo "OS: $OS | ARCH: $ARCH"
echo ""

# 6-1. 시스템 의존성 설치 (Linux)
if [[ "$OS" == "Linux" ]] && command -v apt-get &>/dev/null; then
    echo "[6-1] Installing system dependencies..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq libgbm1 libasound2t64 2>/dev/null \
        || sudo apt-get install -y -qq libgbm1 libasound2 2>/dev/null \
        || echo "  [WARN] Some packages failed — manual check required"
    echo "  [OK] System dependencies installed"
else
    echo "[6-1] Skipping system dependencies (not Linux/apt)"
fi

# 6-2. @playwright/cli 전역 설치
echo ""
echo "[6-2] Installing @playwright/cli..."
npm install -g @playwright/cli@latest

GLOBAL_MODULES=$(npm root -g)
PW_CLI="$GLOBAL_MODULES/@playwright/cli/node_modules/playwright-core/cli.js"

# 6-3. 아키텍처별 브라우저 설치
echo ""
echo "[6-3] Installing browser (ARCH: $ARCH)..."
if [[ "$ARCH" == "x86_64" || "$ARCH" == "amd64" ]]; then
    echo "  x86_64 → installing chrome channel"
    node "$PW_CLI" install chrome
else
    echo "  $ARCH → installing chromium (ARM)"
    node "$PW_CLI" install chromium

    CHROMIUM_DIR=$(find "$HOME/.cache/ms-playwright" -maxdepth 1 -name "chromium-*" -type d | sort -V | tail -1)
    CHROMIUM_BIN="$CHROMIUM_DIR/chrome-linux/chrome"

    if [[ ! -f "$CHROMIUM_BIN" ]]; then
        echo "[ERROR] Could not find installed Chromium binary: $CHROMIUM_BIN"
        exit 1
    fi

    echo "[6-3] Creating symlink: $CHROMIUM_BIN → /opt/google/chrome/chrome"
    sudo mkdir -p /opt/google/chrome
    sudo ln -sf "$CHROMIUM_BIN" /opt/google/chrome/chrome
    echo "  [OK] Symlink created"
fi

# 6-4. AppArmor 제한 해제 (Ubuntu 23.10+)
echo ""
if [[ "$OS" == "Linux" ]]; then
    CURRENT=$(sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null || echo "N/A")
    if [[ "$CURRENT" == "1" ]]; then
        echo "[6-4] Disabling AppArmor userns restriction..."
        sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
        echo "kernel.apparmor_restrict_unprivileged_userns=0" | sudo tee /etc/sysctl.d/99-playwright.conf >/dev/null
        echo "  [OK] Persisted to /etc/sysctl.d/99-playwright.conf"
    else
        echo "[6-4] AppArmor restriction not active ($CURRENT) — skipping"
    fi
fi

# -------------------------------------------------------------
# [7] Playwright MCP 설치 및 Gemini CLI 연동 설정
# -------------------------------------------------------------
echo ""
echo "[7] Installing Playwright MCP for Gemini CLI..."
npm install -g @playwright/mcp@latest
echo "  [OK] @playwright/mcp installed"

# ~/.gemini/settings.json 에 MCP 서버 등록
GEMINI_CONFIG_DIR="$HOME/.gemini"
GEMINI_SETTINGS="$GEMINI_CONFIG_DIR/settings.json"
mkdir -p "$GEMINI_CONFIG_DIR"

if [ -f "$GEMINI_SETTINGS" ]; then
    # 이미 playwright MCP가 등록되어 있는지 확인
    if grep -q "playwright" "$GEMINI_SETTINGS" 2>/dev/null; then
        echo "  [SKIP] Playwright MCP already configured in $GEMINI_SETTINGS"
    else
        echo "  [WARN] $GEMINI_SETTINGS exists — add playwright MCP manually:"
        echo '  "mcpServers": { "playwright": { "command": "npx", "args": ["@playwright/mcp"] } }'
    fi
else
    cat > "$GEMINI_SETTINGS" << 'EOF'
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp"]
    }
  }
}
EOF
    echo "  [OK] Gemini CLI MCP config created: $GEMINI_SETTINGS"
fi

# -------------------------------------------------------------
# [8] PATH 설정 확인
# -------------------------------------------------------------
echo ""
echo "[8] Checking PATH..."
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo "  [OK] ~/.local/bin added to PATH"
else
    echo "  [SKIP] ~/.local/bin already in PATH"
fi

# NVM PATH가 .bashrc에 없으면 추가
if ! grep -q "NVM_DIR" "$HOME/.bashrc"; then
    {
        echo 'export NVM_DIR="$HOME/.nvm"'
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
    } >> "$HOME/.bashrc"
    echo "  [OK] NVM init added to ~/.bashrc"
fi

# -------------------------------------------------------------
# 완료
# -------------------------------------------------------------
echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. source ~/.bashrc   (환경변수 재로드)"
echo "  2. gemini             (Gemini CLI 시작)"
echo ""
if [ -z "$GEMINI_API_KEY" ]; then
    echo "  [!] GEMINI_API_KEY 설정 필요:"
    echo "      echo 'export GEMINI_API_KEY=\"your_key\"' >> ~/.bashrc"
    echo "      source ~/.bashrc"
    echo ""
fi
echo "Installed:"
echo "  - Node.js: $(node -v 2>/dev/null || echo 'reload shell')"
echo "  - Gemini CLI: $(gemini --version 2>/dev/null || echo 'reload shell')"
echo "  - Playwright MCP: $(npx @playwright/mcp --version 2>/dev/null || echo 'installed')"

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
    echo ""
    echo "         또는 기업용 Vertex AI 사용 시:"
    echo "         export GOOGLE_GENAI_USE_VERTEXAI=true"
    echo "         export GOOGLE_CLOUD_PROJECT=\"your-project-id\""
fi

# TELEGRAM_BOT_TOKEN 영구 등록
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    if ! grep -q "TELEGRAM_BOT_TOKEN" "$HOME/.bashrc"; then
        echo "export TELEGRAM_BOT_TOKEN=\"$TELEGRAM_BOT_TOKEN\"" >> "$HOME/.bashrc"
        echo "  [OK] TELEGRAM_BOT_TOKEN added to ~/.bashrc"
    else
        echo "  [SKIP] TELEGRAM_BOT_TOKEN already in ~/.bashrc"
    fi
fi
# Vertex AI 관련 설정 영구 등록
if [ -n "$GOOGLE_GENAI_USE_VERTEXAI" ]; then
    if ! grep -q "GOOGLE_GENAI_USE_VERTEXAI" "$HOME/.bashrc"; then
        echo "export GOOGLE_GENAI_USE_VERTEXAI=\"$GOOGLE_GENAI_USE_VERTEXAI\"" >> "$HOME/.bashrc"
        echo "  [OK] GOOGLE_GENAI_USE_VERTEXAI added to ~/.bashrc"
    fi
fi

if [ -n "$GOOGLE_CLOUD_PROJECT" ]; then
    if ! grep -q "GOOGLE_CLOUD_PROJECT" "$HOME/.bashrc"; then
        echo "export GOOGLE_CLOUD_PROJECT=\"$GOOGLE_CLOUD_PROJECT\"" >> "$HOME/.bashrc"
        echo "  [OK] GOOGLE_CLOUD_PROJECT added to ~/.bashrc"
    fi
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
# [8] claude → gemini 브릿지 생성 (cokacdir 텔레그램 봇 연동용)
#
# cokacdir는 Claude Code CLI 형식으로 claude를 호출합니다:
#   claude -p --allowedTools ... --output-format stream-json --append-system-prompt <text>
#   (사용자 메시지는 stdin으로 전달)
#
# 이 Python 스크립트는:
#   1. Claude 전용 플래그(--allowedTools, --append-system-prompt 등)를 파싱
#   2. Gemini CLI로 실제 AI 응답 생성
#   3. cokacdir가 이해하는 Claude stream-json 형식으로 변환 출력
# -------------------------------------------------------------
echo ""
echo "[8] Creating claude→gemini bridge for cokacdir..."
mkdir -p "$HOME/.local/bin"
CLAUDE_WRAPPER="$HOME/.local/bin/claude"
if [ -f "$CLAUDE_WRAPPER" ] && grep -q "Gemini CLI bridge" "$CLAUDE_WRAPPER" 2>/dev/null; then
    echo "  [SKIP] claude bridge already exists"
else
    cat > "$CLAUDE_WRAPPER" << 'WRAPPER'
#!/usr/bin/env python3
"""Claude Code CLI → Gemini CLI bridge (cokacdir 텔레그램 봇 연동용)"""
import sys, os, subprocess, json, uuid, datetime

LOG = '/tmp/claude-gemini.log'
def log(m):
    open(LOG, 'a').write(f"[{datetime.datetime.now().strftime('%H:%M:%S')}] {m}\n")

def main():
    args = sys.argv[1:]
    system_parts, in_system, skip_next = [], False, False
    for arg in args:
        if skip_next: skip_next = False; continue
        if in_system: system_parts.append(arg); continue
        if arg in ('-p', '--print', '--verbose', '-v', '--no-verbose'): continue
        if arg in ('--allowedTools', '--model', '-m', '--add-dir', '--cwd', '--output-format'):
            skip_next = True; continue
        if arg == '--append-system-prompt': in_system = True; continue

    system_prompt = ' '.join(system_parts)
    user_msg = ''
    try:
        if not sys.stdin.isatty():
            user_msg = sys.stdin.read().strip()
    except: pass

    log(f"user: {user_msg[:80]}")
    log(f"system(60): {system_prompt[:60]}")

    if system_prompt and user_msg:
        prompt = f"{system_prompt}\n\n{user_msg}"
    elif user_msg:
        prompt = user_msg
    elif system_prompt:
        prompt = system_prompt
    else:
        prompt = 'Hello'

    result = subprocess.run(
        ['gemini', '--yolo', '--output-format', 'text', '-p', prompt],
        capture_output=True, text=True
    )
    log(f"exit:{result.returncode} stdout:{result.stdout[:80]}")

    raw = result.stdout.strip()
    lines = [l for l in raw.split('\n')
             if not l.startswith('YOLO mode')
             and not l.startswith('(node:')
             and 'DeprecationWarning' not in l
             and l.strip()]
    response = '\n'.join(lines).strip()
    log(f"response:{response[:80]}")

    sid = str(uuid.uuid4())
    if result.returncode != 0 or not response:
        print(json.dumps({"type": "result", "subtype": "error", "is_error": True,
            "result": result.stderr.strip() or "No response", "session_id": sid}), flush=True)
        sys.exit(result.returncode or 1)

    # Claude 호환 stream-json 출력 (cokacdir가 파싱하는 형식)
    print(json.dumps({"type": "system", "subtype": "init", "session_id": sid,
        "tools": [], "mcp_servers": [], "model": "claude-opus-4-5",
        "permissionMode": "default", "cwd": os.getcwd()}), flush=True)
    print(json.dumps({"type": "assistant", "message": {
        "id": "msg_" + uuid.uuid4().hex[:20], "type": "message", "role": "assistant",
        "content": [{"type": "text", "text": response}],
        "model": "claude-opus-4-5", "stop_reason": "end_turn", "stop_sequence": None,
        "usage": {"input_tokens": 100, "cache_creation_input_tokens": 0,
                  "cache_read_input_tokens": 0, "output_tokens": 50}},
        "session_id": sid}), flush=True)
    print(json.dumps({"type": "result", "subtype": "success", "is_error": False,
        "duration_ms": 5000, "duration_api_ms": 4000, "num_turns": 1,
        "result": response, "session_id": sid, "total_cost_usd": 0.001}), flush=True)

if __name__ == '__main__':
    main()
WRAPPER
    chmod +x "$CLAUDE_WRAPPER"
    echo "  [OK] claude→gemini bridge created: ~/.local/bin/claude"
fi

# -------------------------------------------------------------
# [9] PATH 설정 확인
# -------------------------------------------------------------
echo ""
echo "[9] Checking PATH..."
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
# [10] systemd 서비스 등록 (상시 실행 및 재부팅 대응)
# -------------------------------------------------------------
echo ""
echo "[10] Setting up systemd service for Gemini Telegram Bot..."

# 서비스 명칭 정의
SERVICE_NAME="gemini-bot"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
USER_NAME=$(whoami)
HOME_DIR=$HOME

# 래퍼 스크립트 생성 (NVM 환경 및 텔레그램 토큰 보장)
mkdir -p "$HOME_DIR/.local/bin"
BOT_RUNNER="$HOME_DIR/.local/bin/gemini-bot-runner.sh"

cat > "$BOT_RUNNER" << RUNNER
#!/bin/bash
# 1. 환경변수 로드
export HOME="$HOME_DIR"
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"

# 2. Node 버전 고정
nvm use 24 > /dev/null

# 3. 텔레그램 봇 실행
# gemini-cli는 --yolo 플래그로 비대화형 환경에서 도구 승인 가능
# background 실행을 위해 --output-format stream-json 또는 기본 실행
exec gemini --yolo
RUNNER
chmod +x "$BOT_RUNNER"

# systemd 유닛 파일 생성
sudo bash -c "cat > $SERVICE_FILE" << EOF
[Unit]
Description=Gemini CLI Telegram Bot Service
After=network.target

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$HOME_DIR
# bash -lc를 사용하여 전역 환경변수(TELEGRAM_BOT_TOKEN 등)를 로드
ExecStart=/bin/bash -lc '$BOT_RUNNER'
Restart=always
RestartSec=10
# 로그 파일 설정
StandardOutput=append:/tmp/${SERVICE_NAME}.log
StandardError=append:/tmp/${SERVICE_NAME}.log

[Install]
WantedBy=multi-user.target
EOF

# 서비스 활성화
sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}.service
sudo systemctl restart ${SERVICE_NAME}.service

echo "  [OK] ${SERVICE_NAME}.service registered, enabled, and started"
echo "  [TIP] Check logs with: tail -f /tmp/${SERVICE_NAME}.log"

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
if [ -z "$GEMINI_API_KEY" ] && [ -z "$GOOGLE_CLOUD_PROJECT" ]; then
    echo "  [!] 인증 설정 필요 (둘 중 하나):"
    echo "      1. API 키 방식:"
    echo "         echo 'export GEMINI_API_KEY=\"your_key\"' >> ~/.bashrc"
    echo "      2. Vertex AI 방식 (기업용):"
    echo "         echo 'export GOOGLE_GENAI_USE_VERTEXAI=true' >> ~/.bashrc"
    echo "         echo 'export GOOGLE_CLOUD_PROJECT=\"your-project-id\"' >> ~/.bashrc"
    echo ""
    echo "      설정 후: source ~/.bashrc"
    echo ""
fi
echo "Installed:"
echo "  - Node.js: $(node -v 2>/dev/null || echo 'reload shell')"
echo "  - Gemini CLI: $(gemini --version 2>/dev/null || echo 'reload shell')"
echo "  - Playwright MCP: $(npx @playwright/mcp --version 2>/dev/null || echo 'installed')"

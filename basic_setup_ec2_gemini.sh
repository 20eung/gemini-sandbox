#!/bin/bash
set -e

# =============================================================
# EC2 Gemini CLI Sandbox Setup Script
# 대상: Ubuntu 20.04 ~ 24.04 (x86_64 / aarch64)
# 참고: https://github.com/20eung/gemini-sandbox
#
# 사용법 (로컬에서 실행):
#   export PEM=secret.pem
#   export IP=0.0.0.0
#   export TELEGRAM_BOT_TOKEN=1234:ABC...
#   export GEMINI_API_KEY=AIza...
#   export URL=https://raw.githubusercontent.com/20eung/gemini-sandbox/refs/heads/main/basic_setup_ec2_gemini.sh
#   ssh -t -i "$PEM" ubuntu@$IP \
#     "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN GEMINI_API_KEY=$GEMINI_API_KEY bash -ic \"source <(curl -sL $URL) && gemini\""
# =============================================================

ARCH=$(uname -m)
OS=$(uname -s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== EC2 Gemini CLI Setup ==="
echo "OS: $OS | ARCH: $ARCH"
echo ""

# -------------------------------------------------------------
# [0] .env 파일 로드 (선택) — source <(curl ...) 방식 사용 시
#     환경변수를 ssh 명령에서 직접 전달하는 것이 주 방법
# -------------------------------------------------------------
if [ -f "$SCRIPT_DIR/.env" ]; then
    echo "[0] Loading .env from $SCRIPT_DIR..."
    set -a; source "$SCRIPT_DIR/.env"; set +a
    echo "  [OK] .env loaded"
elif [ -f "$HOME/.env" ]; then
    echo "[0] Loading ~/.env..."
    set -a; source "$HOME/.env"; set +a
    echo "  [OK] ~/.env loaded"
else
    echo "[0] No .env found — using environment variables"
fi

# -------------------------------------------------------------
# [1] 스왑 메모리 설정 (16GB)
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
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
    echo "  [OK] 16G swap created"
fi
swapon --show

# -------------------------------------------------------------
# [2] cokacdir 설치
#     설치 스크립트가 user systemd 서비스 자동 등록
# -------------------------------------------------------------
echo ""
echo "[2] Installing cokacdir..."
if command -v cokacdir &>/dev/null; then
    echo "  [SKIP] cokacdir $(cokacdir --version 2>/dev/null || echo 'already installed')"
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

if ! node -v 2>/dev/null | grep -qE "v2[4-9]"; then
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
    echo "  [OK] Gemini CLI installed: $(which gemini)"
fi

# -------------------------------------------------------------
# [4.5] 환경변수 보정 — .bashrc에서 추출 (서비스 실행 환경 대비)
# -------------------------------------------------------------
echo ""
echo "[4.5] Ensuring environment variables..."
extract_from_bashrc() {
    local var_name=$1
    if [ -z "${!var_name}" ]; then
        local found
        found=$(grep -E "export $var_name=" "$HOME/.bashrc" 2>/dev/null | head -1 | sed -E "s/export $var_name=[\"']?([^\"']*)[\"']?/\1/")
        if [ -n "$found" ]; then
            export "$var_name"="$found"
            echo "  [OK] Extracted $var_name from ~/.bashrc"
        fi
    fi
    [ -z "${!var_name}" ] && echo "  [WARN] $var_name not set"
}
extract_from_bashrc "TELEGRAM_BOT_TOKEN"
extract_from_bashrc "GEMINI_API_KEY"

# -------------------------------------------------------------
# [5] 환경변수 .bashrc 영구 등록
# -------------------------------------------------------------
echo ""
echo "[5] Configuring environment variables in ~/.bashrc..."

if [ -n "$GEMINI_API_KEY" ]; then
    if ! grep -q "GEMINI_API_KEY" "$HOME/.bashrc"; then
        echo "export GEMINI_API_KEY=\"$GEMINI_API_KEY\"" >> "$HOME/.bashrc"
        echo "  [OK] GEMINI_API_KEY added to ~/.bashrc"
    else
        echo "  [SKIP] GEMINI_API_KEY already in ~/.bashrc"
    fi
else
    echo "  [WARN] GEMINI_API_KEY not set — add manually:"
    echo "         export GEMINI_API_KEY=\"your_key_here\""
fi

if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    if ! grep -q "TELEGRAM_BOT_TOKEN" "$HOME/.bashrc"; then
        echo "export TELEGRAM_BOT_TOKEN=\"$TELEGRAM_BOT_TOKEN\"" >> "$HOME/.bashrc"
        echo "  [OK] TELEGRAM_BOT_TOKEN added to ~/.bashrc"
    else
        echo "  [SKIP] TELEGRAM_BOT_TOKEN already in ~/.bashrc"
    fi
fi

if ! grep -q '"$HOME/.local/bin"' "$HOME/.bashrc" && ! grep -q "\$HOME/.local/bin" "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo "  [OK] ~/.local/bin added to PATH"
else
    echo "  [SKIP] ~/.local/bin already in PATH"
fi

# 현재 쉘에도 즉시 적용
export PATH="$HOME/.local/bin:$PATH"

# -------------------------------------------------------------
# [6] Playwright 시스템 의존성
# -------------------------------------------------------------
echo ""
echo "[6] Installing Playwright system dependencies..."
if [[ "$OS" == "Linux" ]] && command -v apt-get &>/dev/null; then
    sudo apt-get update -qq
    # Ubuntu 24.04 (t64 패키지) vs 이전 버전 대응
    PKGS_T64="libgbm1 libasound2t64 libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libatspi2.0-0t64 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libcairo2 libpango-1.0-0"
    PKGS_LEGACY="libgbm1 libasound2 libatk1.0-0 libatk-bridge2.0-0 libcups2 libatspi2.0-0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libcairo2 libpango-1.0-0"
    sudo apt-get install -y -qq $PKGS_T64 2>/dev/null \
        || sudo apt-get install -y -qq $PKGS_LEGACY 2>/dev/null \
        || echo "  [WARN] Some browser dependencies failed — run: npx playwright install-deps"
    echo "  [OK] System dependencies installed"
else
    echo "  [SKIP] Not Linux/apt"
fi

# -------------------------------------------------------------
# [7] playwright-cli 설치 및 브라우저 설치
# -------------------------------------------------------------
echo ""
echo "[7] Installing playwright-cli..."
if command -v playwright-cli &>/dev/null; then
    echo "  [SKIP] playwright-cli already installed"
else
    npm install -g @playwright/cli@latest
    echo "  [OK] playwright-cli installed"
fi

GLOBAL_MODULES=$(npm root -g)
PW_CLI="$GLOBAL_MODULES/@playwright/cli/node_modules/playwright-core/cli.js"

echo ""
echo "[7-browser] Installing browser (ARCH: $ARCH)..."
if [[ "$ARCH" == "x86_64" || "$ARCH" == "amd64" ]]; then
    CHROME_EXISTS=$(find "$HOME/.cache/ms-playwright" -maxdepth 1 -name "chrome-*" -type d 2>/dev/null | head -1)
    if [ -n "$CHROME_EXISTS" ]; then
        echo "  [SKIP] Chrome already installed: $CHROME_EXISTS"
    else
        node "$PW_CLI" install chrome
        echo "  [OK] Chrome installed"
    fi
else
    CHROMIUM_EXISTS=$(find "$HOME/.cache/ms-playwright" -maxdepth 1 -name "chromium-*" -type d 2>/dev/null | sort -V | tail -1)
    if [ -n "$CHROMIUM_EXISTS" ]; then
        echo "  [SKIP] Chromium already installed: $CHROMIUM_EXISTS"
    else
        node "$PW_CLI" install chromium
        CHROMIUM_DIR=$(find "$HOME/.cache/ms-playwright" -maxdepth 1 -name "chromium-*" -type d | sort -V | tail -1)
        CHROMIUM_BIN="$CHROMIUM_DIR/chrome-linux/chrome"
        if [ ! -f "$CHROMIUM_BIN" ]; then
            echo "  [ERROR] Chromium binary not found: $CHROMIUM_BIN"
            exit 1
        fi
        sudo mkdir -p /opt/google/chrome
        sudo ln -sf "$CHROMIUM_BIN" /opt/google/chrome/chrome
        echo "  [OK] Chromium installed + symlink created"
    fi
fi

# AppArmor userns 제한 해제 (Ubuntu 23.10+)
if [[ "$OS" == "Linux" ]]; then
    APPARMOR_VAL=$(sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null || echo "N/A")
    if [[ "$APPARMOR_VAL" == "1" ]]; then
        echo "  Disabling AppArmor userns restriction..."
        sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
        echo "kernel.apparmor_restrict_unprivileged_userns=0" | sudo tee /etc/sysctl.d/99-playwright.conf > /dev/null
        echo "  [OK] AppArmor restriction disabled (persisted)"
    else
        echo "  [SKIP] AppArmor restriction not active ($APPARMOR_VAL)"
    fi
fi

# -------------------------------------------------------------
# [8] claude shim v4 설치 (cokacdir → Gemini CLI 브릿지)
#     기존 v4 존재 시 SKIP, 구버전(v1~v3) 존재 시 v4로 업그레이드
# -------------------------------------------------------------
echo ""
echo "[8] Installing claude shim v4..."
mkdir -p "$HOME/.local/bin"
CLAUDE_WRAPPER="$HOME/.local/bin/claude"

if [ -f "$CLAUDE_WRAPPER" ] && grep -q "Bridge v4" "$CLAUDE_WRAPPER" 2>/dev/null; then
    echo "  [SKIP] claude shim v4 already installed"
else
    [ -f "$CLAUDE_WRAPPER" ] && cp "$CLAUDE_WRAPPER" "${CLAUDE_WRAPPER}.bak" && echo "  [INFO] Backed up existing shim to claude.bak"
    cat > "$CLAUDE_WRAPPER" << 'SHIM_EOF'
#!/usr/bin/env python3
"""
cokacdir → Gemini CLI Bridge v4
스트리밍, 세션 관리, bkit 노이즈 제거, 모델 선택, SIGTERM 처리, 스킬 디스패치 지원
"""
import sys, os, subprocess, json, uuid, datetime, re, signal

SESSION_MAP_FILE = os.path.expanduser("~/.cokacdir/session_map.json")
LOG_FILE = "/tmp/claude-gemini.log"
SKILLS_DIR = os.path.expanduser("~/.gemini/skills")

def _find_gemini_bin():
    """NVM 또는 PATH에서 gemini 바이너리를 런타임에 동적 탐색"""
    import shutil
    path = shutil.which('gemini')
    if path:
        return path
    nvm_dir = os.path.expanduser('~/.nvm/versions/node')
    if os.path.isdir(nvm_dir):
        for ver in sorted(os.listdir(nvm_dir), reverse=True):
            candidate = os.path.join(nvm_dir, ver, 'bin', 'gemini')
            if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
                return candidate
    return 'gemini'

GEMINI_BIN = _find_gemini_bin()
NVM_PATH = os.path.dirname(GEMINI_BIN) if GEMINI_BIN != 'gemini' else ''

def log(m):
    try:
        with open(LOG_FILE, 'a') as f:
            f.write(f"[{datetime.datetime.now().strftime('%H:%M:%S')}] {m}\n")
    except:
        pass

def get_env_with_node():
    """node가 포함된 환경 변수 반환"""
    env = dict(os.environ)
    env['HOME'] = os.path.expanduser('~')
    env['PATH'] = f"{NVM_PATH}:{env.get('PATH', '')}"
    env['NVM_DIR'] = os.path.expanduser('~/.nvm')
    return env

def load_session_map():
    try:
        if os.path.exists(SESSION_MAP_FILE):
            with open(SESSION_MAP_FILE) as f:
                return json.load(f)
    except:
        pass
    return {}

def save_session_map(session_map):
    try:
        os.makedirs(os.path.dirname(SESSION_MAP_FILE), exist_ok=True)
        with open(SESSION_MAP_FILE, 'w') as f:
            json.dump(session_map, f, indent=2)
    except Exception as e:
        log(f"session map 저장 실패: {e}")

def find_gemini_session_index(gemini_uuid, cwd=None):
    """UUID로 Gemini 세션 인덱스 검색"""
    search_cwd = cwd or os.path.expanduser('~')
    try:
        result = subprocess.run(
            [GEMINI_BIN, '--list-sessions'],
            capture_output=True, text=True, timeout=20,
            env=get_env_with_node(), cwd=search_cwd
        )
        if result.returncode != 0:
            return None
        for line in result.stdout.split('\n'):
            if gemini_uuid in line:
                m = re.match(r'\s*(\d+)\.', line)
                if m:
                    return m.group(1)
    except Exception as e:
        log(f"세션 인덱스 검색 실패: {e}")
    return None

def filter_bkit_noise(text, partial=False):
    """bkit Feature Usage 섹션 및 기타 노이즈 제거"""
    if partial:
        text = re.sub(r'\n*\u2500{5,}(?:\n\U0001f4ca bkit[\s\S]*)?$', '', text)
    else:
        text = re.sub(r'\n*\u2500{5,}\n\U0001f4ca bkit Feature Usage\n\u2500{5,}[\s\S]*$', '', text)
        text = re.sub(r'\n*\u2500{5,}\n\U0001f4ca bkit[\s\S]*$', '', text)
    return text.rstrip()

def map_model_to_gemini(model_name):
    """Claude 모델명 → Gemini 모델명 매핑"""
    if not model_name:
        return None
    if model_name.startswith('gemini-'):
        return model_name
    mapping = {
        'opus':       'gemini-3.1-pro-preview',
        'sonnet':     'gemini-3-flash-preview',
        'haiku':      'gemini-2.5-flash',
        'opus[1m]':   'gemini-3.1-pro-preview',
        'sonnet[1m]': 'gemini-3-flash-preview',
        'haiku[1m]':  'gemini-2.5-flash-lite',
        'default':    None,
    }
    return mapping.get(model_name.lower())

def detect_skill_command(msg):
    """사용자 메시지에서 스킬 커맨드 감지"""
    msg = msg.strip()
    if not msg.startswith('/'):
        return None, None
    parts = msg.split(None, 1)
    cmd = parts[0].lower().lstrip('/')
    args = parts[1] if len(parts) > 1 else ''
    skill_map = {
        'pdca': 'pdca', 'plan': 'pdca', 'design': 'pdca',
        'analyze': 'pdca', 'report': 'pdca',
        'code-review': 'code-review', 'codereview': 'code-review', 'review': 'code-review',
        'web': 'web', 'fetch': 'web',
        'help': 'help',
        'playwright': 'playwright', 'browser': 'playwright',
        'playwright-cli': 'playwright', 'screenshot': 'playwright',
        'start': None, 'new': None,
    }
    return skill_map.get(cmd), args

def parse_file_upload(msg):
    """cokacdir의 [File uploaded] 메시지 또는 파일 경로 직접 입력을 @ 파일 참조로 변환"""
    # 형식 1: [File uploaded] filename.ext → /path/to/file
    m = re.search(r'\[File uploaded\]\s+\S+\s+→\s+(/\S+)', msg)
    if m:
        filepath = m.group(1).strip()
        caption = msg[m.end():].strip()
        ext = os.path.splitext(filepath)[1].lower()
        image_exts = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff', '.tif', '.heic', '.heif'}
        text_exts  = {'.txt', '.md', '.py', '.js', '.ts', '.json', '.yaml', '.yml', '.csv',
                      '.html', '.css', '.sh', '.bash', '.pdf'}
        return {
            'filepath': filepath, 'caption': caption,
            'is_image': ext in image_exts,
            'is_text':  ext in text_exts,
            'ext': ext,
        }
    # 형식 2: /절대경로/파일.ext 설명텍스트 (사용자가 파일 경로를 직접 입력)
    m2 = re.match(r'(/\S+\.(jpg|jpeg|png|gif|webp|bmp|tiff|tif|heic|heif|pdf|txt|md|py|js|ts|json|yaml|yml|csv|html|css|sh))\s*(.*)', msg, re.IGNORECASE)
    if m2 and os.path.isfile(m2.group(1)):
        filepath = m2.group(1)
        caption = m2.group(3).strip()
        ext = os.path.splitext(filepath)[1].lower()
        image_exts = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff', '.tif', '.heic', '.heif'}
        return {
            'filepath': filepath, 'caption': caption,
            'is_image': ext in image_exts,
            'is_text':  ext not in image_exts,
            'ext': ext,
        }
    return None

def load_skill_context(skill_name):
    """스킬 파일에서 추가 컨텍스트 로드"""
    if not skill_name:
        return ''
    skill_file = os.path.join(SKILLS_DIR, f"{skill_name}.md")
    try:
        if os.path.exists(skill_file):
            with open(skill_file) as f:
                return f.read().strip()
    except Exception as e:
        log(f"스킬 파일 로드 실패 ({skill_name}): {e}")
    return ''

def parse_cokacdir_args(args):
    """cokacdir가 전달하는 claude CLI 인수 파싱"""
    result = {'resume_session_id': None, 'system_prompt': '', 'cwd': None, 'model': None, 'allowed_tools': []}
    i = 0
    while i < len(args):
        arg = args[i]
        if arg in ('--resume', '-r') and i + 1 < len(args):
            result['resume_session_id'] = args[i + 1]; i += 2
        elif arg == '--append-system-prompt' and i + 1 < len(args):
            parts = []; i += 1
            while i < len(args):
                if args[i].startswith('--') and len(args[i]) > 3:
                    break
                parts.append(args[i]); i += 1
            result['system_prompt'] = ' '.join(parts)
        elif arg == '--cwd' and i + 1 < len(args):
            result['cwd'] = args[i + 1]; i += 2
        elif arg in ('--model', '-m') and i + 1 < len(args):
            result['model'] = args[i + 1]; i += 2
        elif arg == '--allowedTools' and i + 1 < len(args):
            result['allowed_tools'] = args[i + 1].split(','); i += 2
        else:
            i += 1
    # --cwd 미전달 시 system prompt에서 추출
    if not result['cwd'] and result['system_prompt']:
        m = re.search(r'Current working directory: (/[^\n\\]+)', result['system_prompt'])
        if m:
            result['cwd'] = m.group(1).strip()
    return result

def emit_claude_init(session_id, cwd, model='gemini-3.1-pro-preview'):
    print(json.dumps({"type": "system", "subtype": "init", "session_id": session_id,
        "tools": [], "mcp_servers": [], "model": model, "permissionMode": "default",
        "cwd": cwd or os.path.expanduser('~')}), flush=True)

def emit_claude_assistant(text, session_id, is_final=False, model='gemini-3.1-pro-preview'):
    print(json.dumps({"type": "assistant", "message": {
        "id": "msg_" + uuid.uuid4().hex[:20], "type": "message", "role": "assistant",
        "content": [{"type": "text", "text": text}], "model": model,
        "stop_reason": "end_turn" if is_final else None, "stop_sequence": None,
        "usage": {"input_tokens": 0, "cache_creation_input_tokens": 0,
                  "cache_read_input_tokens": 0, "output_tokens": 0}},
        "session_id": session_id}), flush=True)

def emit_claude_result(text, session_id, stats=None):
    stats = stats or {}
    print(json.dumps({"type": "result", "subtype": "success", "is_error": False,
        "duration_ms": stats.get('duration_ms', 5000), "duration_api_ms": stats.get('duration_ms', 4000),
        "num_turns": 1, "result": text, "session_id": session_id, "total_cost_usd": 0.0}), flush=True)

def emit_claude_error(msg, session_id):
    print(json.dumps({"type": "result", "subtype": "error", "is_error": True,
        "result": msg, "session_id": session_id}), flush=True)

def main():
    args = sys.argv[1:]
    log(f"ARGS: {args}")
    parsed = parse_cokacdir_args(args)
    user_msg = ''
    try:
        if not sys.stdin.isatty():
            user_msg = sys.stdin.read().strip()
    except:
        pass
    # [File uploaded] 처리: @filepath 문법으로 변환하여 멀티모달 지원
    file_info = parse_file_upload(user_msg)
    if file_info:
        filepath = file_info['filepath']
        caption  = file_info['caption']
        if file_info['is_image']:
            user_msg = f'@{filepath} {caption or "이 이미지의 내용을 분석해 주세요."}'
        elif file_info['is_text']:
            user_msg = f'@{filepath} {caption or "이 파일의 내용을 분석해 주세요."}'
        else:
            user_msg = caption or f'파일이 업로드되었습니다: {os.path.basename(filepath)}'
        log(f"파일 업로드 감지 ({file_info['ext']}): {filepath}")

    log(f"resume={parsed['resume_session_id']}, cwd={parsed['cwd']}, model={parsed['model']}, msg={user_msg[:60]}")

    cwd = parsed['cwd'] or os.path.expanduser('~')
    cokacdir_session_id = parsed['resume_session_id']
    response_session_id = cokacdir_session_id or str(uuid.uuid4())
    gemini_model = map_model_to_gemini(parsed['model']) or 'gemini-3.1-pro-preview'
    log(f"모델: {parsed['model']} -> {gemini_model}")

    emit_claude_init(response_session_id, cwd, model=gemini_model)
    gemini_env = get_env_with_node()

    skill_name, skill_args = detect_skill_command(user_msg)
    skill_context = load_skill_context(skill_name) if skill_name else ''
    if skill_name:
        log(f"스킬 감지: /{skill_name} (args: {skill_args[:30]})")

    session_map = load_session_map()
    gemini_cmd = [GEMINI_BIN, '--yolo', '--output-format', 'stream-json']

    if gemini_model and gemini_model != 'gemini-3.1-pro-preview':
        gemini_cmd.extend(['-m', gemini_model])
    elif parsed['model'] and parsed['model'].startswith('gemini-'):
        gemini_cmd.extend(['-m', parsed['model']])

    if cokacdir_session_id and cokacdir_session_id in session_map:
        gemini_uuid = session_map[cokacdir_session_id]
        session_index = find_gemini_session_index(gemini_uuid, cwd=cwd)
        if session_index:
            gemini_cmd.extend(['--resume', session_index])
            log(f"세션 재개: {gemini_uuid[:8]}... (index {session_index})")
            prompt = f"{skill_context}\n\n사용자 요청: {user_msg}" if skill_context else user_msg
        else:
            log(f"세션 만료, 새 세션 시작")
            system = parsed['system_prompt']
            prompt = f"{system}\n\n{skill_context}\n\n사용자 요청: {user_msg}" if skill_context and system else \
                     f"{skill_context}\n\n사용자 요청: {user_msg}" if skill_context else \
                     f"{system}\n\n{user_msg}" if system else user_msg
    else:
        system = parsed['system_prompt']
        prompt = f"{system}\n\n{skill_context}\n\n사용자 요청: {user_msg}" if skill_context and system else \
                 f"{skill_context}\n\n사용자 요청: {user_msg}" if skill_context else \
                 f"{system}\n\n{user_msg}" if system else user_msg
        log(f"신규 세션 시작")

    gemini_cmd.extend(['-p', prompt])
    log(f"CMD: {gemini_cmd[0]} ... -p {prompt[:40]}...")

    process = None
    def handle_signal(signum, frame):
        log(f"시그널 {signum} 수신, Gemini 프로세스 종료")
        if process and process.poll() is None:
            try:
                process.terminate(); process.wait(timeout=3)
            except:
                try: process.kill()
                except: pass
        sys.exit(0)

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    try:
        process = subprocess.Popen(gemini_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, bufsize=1, cwd=cwd, env=gemini_env)
    except Exception as e:
        log(f"Gemini 실행 실패: {e}")
        emit_claude_error(f"Gemini 실행 실패: {e}", response_session_id)
        sys.exit(1)

    accumulated = ''
    gemini_session_uuid = None
    final_stats = {}
    line_buf = ''

    try:
        while True:
            ch = process.stdout.read(1)
            if not ch: break
            line_buf += ch
            if ch != '\n': continue
            line = line_buf.strip(); line_buf = ''
            if not line: continue
            if any(line.startswith(p) for p in ['YOLO mode', '(node:', 'Loaded cached',
                'Loading extension', 'Created execution', 'Expanding hook',
                'Hook execution', 'DeprecationWarning']): continue
            if not line.startswith('{'): continue
            try:
                g = json.loads(line)
            except json.JSONDecodeError:
                continue
            gtype = g.get('type', '')
            if gtype == 'init':
                gemini_session_uuid = g.get('session_id')
            elif gtype == 'message' and g.get('role') == 'assistant':
                content = g.get('content', '')
                if g.get('delta', False): accumulated += content
                else: accumulated = content
            elif gtype == 'result':
                final_stats = g.get('stats', {})
                clean_text = filter_bkit_noise(accumulated, partial=False)
                emit_claude_assistant(clean_text, response_session_id, is_final=True, model=gemini_model)
                emit_claude_result(clean_text, response_session_id, final_stats)
                log(f"완료. 토큰: {final_stats.get('total_tokens', '?')}")
    except Exception as e:
        log(f"스트리밍 중 오류: {e}")

    process.wait()
    if gemini_session_uuid:
        key = cokacdir_session_id or response_session_id
        session_map[key] = gemini_session_uuid
        save_session_map(session_map)
        log(f"세션 저장: {key[:8]}... -> {gemini_session_uuid[:8]}...")

    if process.returncode != 0 and not accumulated:
        stderr = process.stderr.read()
        log(f"Gemini 오류 ({process.returncode}): {stderr[:200]}")
        emit_claude_error(f"오류 발생: {stderr[:200]}", response_session_id)

if __name__ == '__main__':
    main()
SHIM_EOF

    # GEMINI_BIN / NVM_PATH: shim이 런타임에 동적 탐색하므로 sed 치환 불필요
    chmod +x "$CLAUDE_WRAPPER"
    echo "  [OK] claude shim v4 installed: ~/.local/bin/claude"
fi

# -------------------------------------------------------------
# [9] GEMINI.md + skills 설치
# -------------------------------------------------------------
echo ""
echo "[9] Installing GEMINI.md and skills..."
GEMINI_CONFIG="$HOME/.gemini"
mkdir -p "$GEMINI_CONFIG/skills"

# GEMINI.md
if [ -f "$GEMINI_CONFIG/GEMINI.md" ]; then
    echo "  [SKIP] GEMINI.md already exists"
else
    cat > "$GEMINI_CONFIG/GEMINI.md" << 'GEMINIMD_EOF'
## 기본 설정

- 사용자는 텔레그램과 CLI(터미널) 두 환경에서 상호작용합니다.
- **텔레그램(Bot) 응답 시:**
  - cokacdir 봇은 parse_mode=HTML 미지원 → Telegram Markdown 문법만 사용
  - 사용 가능: **굵게**, `인라인 코드`, 코드블록(백틱 3개), ~~취소선~~
  - 사용 금지: HTML 태그(<b>, <i>, <code> 등), 표(|), # 헤더, --- 구분선
- **CLI 터미널 응답 시:** 표준 마크다운(Markdown) 형식 사용
- 모든 답변과 문서는 한국어로 작성한다
- 반말 금지, 존댓말 사용

---

## /help 응답 템플릿

사용자가 `/help`를 입력하면 다음과 같이 응답하세요:

```
**Gemini AI 봇 도움말**

**기본 기능**
• 자유 대화 - 무엇이든 질문하세요
• 파일 읽기/쓰기/편집
• 코드 작성 및 디버깅
• 웹 검색 및 URL 내용 분석
• Bash 명령어 실행

**개발 도구**
• `/pdca plan [기능명]` - 새 기능 계획 문서 작성
• `/pdca design [기능명]` - 설계 문서 작성
• `/pdca do [기능명]` - 구현 가이드
• `/pdca analyze [기능명]` - 설계↔구현 갭 분석
• `/pdca status` - 현재 PDCA 상태 확인
• `/code-review [파일/폴더]` - 코드 품질 리뷰
• `/web [URL]` - 웹 페이지 내용 분석
• `/playwright` - 브라우저 자동화 가이드

**스케줄 (cokacdir 네이티브)**
• `N분/시간/일 후에 [작업]해줘` - 일회성 스케줄 등록
• `매일 오전 9시에 [작업]해줘` - 반복 스케줄 등록

**파일 전송**
• 파일 생성 후 자동으로 텔레그램으로 전송됩니다
```

---

## 현재 서버 환경

- OS: Ubuntu Linux (AWS EC2, aarch64)
- Node.js: NVM_BIN_PLACEHOLDER/node
- Gemini CLI: NVM_BIN_PLACEHOLDER/gemini
- playwright-cli: NVM_BIN_PLACEHOLDER/playwright-cli
- 작업 공간: /home/ubuntu/.cokacdir/workspace/
GEMINIMD_EOF
    echo "  [OK] GEMINI.md installed"
fi

# skills/pdca.md
if [ -f "$GEMINI_CONFIG/skills/pdca.md" ]; then
    echo "  [SKIP] skills/pdca.md already exists"
else
    cat > "$GEMINI_CONFIG/skills/pdca.md" << 'PDCA_EOF'
# PDCA 스킬 상세 가이드

PDCA (Plan-Do-Check-Act) 개발 방법론을 단계별로 안내합니다.

## 커맨드 형식
`/pdca [action] [feature_name]`

## 단계별 실행 방법

### plan - 계획 문서 작성
```
/pdca plan [기능명]
```
실행 내용:
1. `docs/01-plan/features/[기능명].plan.md` 파일 생성
2. 다음 섹션 포함:
   - 목표 및 배경
   - 사용자 스토리
   - 기능 요구사항 목록
   - 비기능 요구사항 (성능/보안)
   - 성공 기준

### design - 설계 문서 작성
```
/pdca design [기능명]
```
실행 내용:
1. plan 문서 확인
2. `docs/02-design/features/[기능명].design.md` 생성:
   - 시스템 아키텍처 다이어그램 (텍스트)
   - 데이터 모델/스키마
   - API 엔드포인트 목록
   - 구현할 파일/모듈 목록
   - 단계별 구현 체크리스트

### do - 구현
```
/pdca do [기능명]
```
실행 내용:
1. design 문서를 기반으로 구현 시작
2. 진행 상황 텔레그램으로 보고
3. 생성된 파일 자동 전송

### analyze - 갭 분석
```
/pdca analyze [기능명]
```
실행 내용:
1. design 문서 읽기
2. 실제 구현 코드 읽기
3. 차이(Gap) 목록 작성
4. 일치율(%) 계산
5. `docs/03-analysis/[기능명].analysis.md` 생성

### status - 상태 확인
```
/pdca status
```
실행 내용:
1. `docs/` 폴더 스캔
2. 진행 중인 기능 목록 출력
3. 각 기능의 PDCA 단계 표시

### report - 완료 보고서
```
/pdca report [기능명]
```
실행 내용:
1. 모든 PDCA 문서 수집
2. 종합 보고서 생성
3. `docs/04-report/[기능명].report.md` 저장

## 문서 저장 위치
- Plan: `docs/01-plan/features/[기능명].plan.md`
- Design: `docs/02-design/features/[기능명].design.md`
- Analysis: `docs/03-analysis/[기능명].analysis.md`
- Report: `docs/04-report/[기능명].report.md`
PDCA_EOF
    echo "  [OK] skills/pdca.md installed"
fi

# skills/code-review.md
if [ -f "$GEMINI_CONFIG/skills/code-review.md" ]; then
    echo "  [SKIP] skills/code-review.md already exists"
else
    cat > "$GEMINI_CONFIG/skills/code-review.md" << 'CR_EOF'
# 코드 리뷰 스킬

사용자가 코드 리뷰를 요청했습니다. 다음 기준으로 분석하세요:

## 분석 항목

1. **코드 품질** (Code Quality)
   - 중복 코드 (DRY 원칙 위반)
   - 복잡도 (함수/파일이 너무 길지 않은지)
   - 네이밍 (변수/함수명이 명확한지)
   - 타입 안전성

2. **버그 탐지** (Bug Detection)
   - null/undefined 처리 누락
   - 에러 핸들링 부족
   - 경계 조건 미처리
   - 비동기 처리 오류

3. **보안** (Security)
   - SQL 인젝션 가능성
   - XSS 취약점
   - 인증/인가 누락
   - 민감 정보 노출

4. **성능** (Performance)
   - 불필요한 반복 연산
   - 메모리 누수 가능성
   - 비효율적인 알고리즘

## 응답 형식

```
**코드 리뷰 결과**: [파일명]

**심각도 높음** 🔴
• [문제점] → [해결책]

**심각도 중간** 🟡
• [문제점] → [해결책]

**개선 제안** 💡
• [제안사항]

**총평**: [점수/10] - [한 줄 요약]
```

파일이나 디렉토리가 지정되지 않으면 현재 작업 디렉토리의 주요 파일을 분석하세요.
CR_EOF
    echo "  [OK] skills/code-review.md installed"
fi

# skills/web.md
if [ -f "$GEMINI_CONFIG/skills/web.md" ]; then
    echo "  [SKIP] skills/web.md already exists"
else
    cat > "$GEMINI_CONFIG/skills/web.md" << 'WEB_EOF'
# 웹 컨텐츠 분석 스킬

사용자가 웹 URL을 분석 요청했습니다.

## 처리 방법
1. Google Search 도구나 URL fetch를 사용하여 페이지 내용 가져오기
2. 핵심 정보 추출 및 정리
3. 한국어로 요약 제공

## 응답 형식
```
**웹 페이지 분석**: [URL]

**요약**: [2-3줄 요약]

**주요 내용**:
• [항목 1]
• [항목 2]
• [항목 3]

**관련 정보**: [추가 참고사항]
```

URL이 없으면 검색어로 웹 검색을 수행하세요.
WEB_EOF
    echo "  [OK] skills/web.md installed"
fi

# skills/playwright.md
if [ -f "$GEMINI_CONFIG/skills/playwright.md" ]; then
    echo "  [SKIP] skills/playwright.md already exists"
else
    cat > "$GEMINI_CONFIG/skills/playwright.md" << 'PW_EOF'
# 브라우저 자동화 스킬 (playwright-cli)

playwright-cli가 설치되어 있습니다. 웹 페이지 자동화 및 스크래핑에 사용하세요.

## 사용 가능한 명령어

```bash
# PATH 설정 필요
export PATH=NVM_BIN_PLACEHOLDER:$PATH

# 브라우저 열기 (headless)
playwright-cli open https://example.com

# 페이지 이동
playwright-cli goto https://example.com

# 스냅샷 (DOM 구조 확인)
playwright-cli snapshot

# 스크린샷 저장
playwright-cli screenshot --filename=screenshot.png

# 요소 클릭 (snapshot에서 ref 확인)
playwright-cli click e1

# 텍스트 입력
playwright-cli type "검색어"
playwright-cli press Enter

# 요소 채우기
playwright-cli fill e5 "이메일@example.com"

# 브라우저 닫기
playwright-cli close
```

## 텔레그램 봇에서 사용 시

작업 완료 후 스크린샷을 cokacdir --sendfile로 전송하세요:
```bash
cokacdir --sendfile /path/to/screenshot.png --chat [CHAT_ID] --key [KEY_HASH]
```

## 주의사항

- 헤드리스 모드로 동작 (화면 없음)
- JavaScript가 실행되는 페이지도 처리 가능
- 로그인이 필요한 페이지는 세션 유지 어려움
PW_EOF
    echo "  [OK] skills/playwright.md installed"
fi

# 동적 경로 치환 (NVM_BIN_PLACEHOLDER → 실제 경로)
REAL_NVM_BIN=$(dirname "$(which gemini 2>/dev/null || echo '/usr/bin/gemini')")
sed -i "s|NVM_BIN_PLACEHOLDER|$REAL_NVM_BIN|g" "$GEMINI_CONFIG/GEMINI.md" 2>/dev/null || true
sed -i "s|NVM_BIN_PLACEHOLDER|$REAL_NVM_BIN|g" "$GEMINI_CONFIG/skills/playwright.md" 2>/dev/null || true
echo "  [OK] NVM paths updated: $REAL_NVM_BIN"

# -------------------------------------------------------------
# [10] cokacdir 텔레그램 봇 서비스 등록
# -------------------------------------------------------------
echo ""
echo "[10] Setting up cokacdir Telegram bot service..."
if [ -f "$HOME/.config/systemd/user/cokacdir.service" ]; then
    echo "  [SKIP] cokacdir.service already exists"
else
    if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
        npx -y service-setup-cokacdir "$TELEGRAM_BOT_TOKEN"
        echo "  [OK] cokacdir service registered"
    else
        echo "  [WARN] TELEGRAM_BOT_TOKEN not set — run manually after setup:"
        echo "         npx -y service-setup-cokacdir <YOUR_BOT_TOKEN>"
    fi
fi

# -------------------------------------------------------------
# 완료
# -------------------------------------------------------------
echo ""
echo "=============================================="
echo "  Setup Complete!"
echo "=============================================="
echo ""
echo "다음 단계:"
echo ""
echo "1. Gemini CLI 인증 (이 명령 실행 후 자동 시작):"
echo "   gemini"
echo ""
echo "2. 그룹 채팅 사용 시 — BotFather Privacy Mode OFF:"
echo "   @BotFather → /mybots → Bot Settings → Group Privacy → Turn off"
echo ""
echo "설치된 항목:"
echo "  - Node.js:        $(node -v 2>/dev/null || echo 'reload shell')"
echo "  - Gemini CLI:     $(gemini --version 2>/dev/null || echo 'reload shell')"
echo "  - claude shim:    ~/.local/bin/claude (v4)"
echo "  - GEMINI.md:      ~/.gemini/GEMINI.md"
echo "  - skills:         ~/.gemini/skills/ (pdca, code-review, web, playwright)"
echo "  - playwright-cli: $(playwright-cli --version 2>/dev/null || echo 'installed')"
echo "  - cokacdir svc:   $(systemctl --user is-active cokacdir.service 2>/dev/null || echo 'check manually')"
echo ""

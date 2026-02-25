# EC2 Gemini CLI Sandbox

> AWS EC2 Ubuntu 인스턴스에 Google Gemini CLI AI 샌드박스를 구성하고 텔레그램 봇으로 연결하는 자동화 스크립트

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Gemini CLI](https://img.shields.io/badge/Gemini_CLI-@google%2Fgemini--cli-4285F4)](https://github.com/google-gemini/gemini-cli)
[![Node.js](https://img.shields.io/badge/Node.js-24.x-339933)](https://nodejs.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-E95420)](https://ubuntu.com/)

---

## 원클릭 설치 (로컬에서 실행)

> 아래 변수들을 설정하고 환경에 맞는 명령어를 실행하면 EC2에 자동으로 설치됩니다.

### 옵션 1: 개인/일반 사용자 (API 키 방식)

```bash
export PEM=~/Downloads/my-key.pem
export IP=13.124.xxx.xxx
export GEMINI_KEY=your_gemini_api_key_here
export TOKEN=1234567890:AABBccDDeeFFggHHiiJJkkLLmmNNooPPqqRR
export URL=https://raw.githubusercontent.com/20eung/gemini-sandbox/refs/heads/main/basic_setup_ec2_gemini.sh
ssh -t -i "$PEM" ubuntu@$IP "bash -ic \"export GEMINI_API_KEY='$GEMINI_KEY' TELEGRAM_BOT_TOKEN='$TOKEN'; bash <(curl -sL $URL) && source ~/.bashrc && npx -y service-setup-cokacdir $TOKEN && gemini\""
```

### 옵션 2: 기업용 사용자 (Vertex AI 방식)

```bash
export PEM=~/Downloads/my-key.pem
export IP=13.124.xxx.xxx
export PROJECT_ID=your-gcp-project-id
export TOKEN=1234567890:AABBccDDeeFFggHHiiJJkkLLmmNNooPPqqRR
export URL=https://raw.githubusercontent.com/20eung/gemini-sandbox/refs/heads/main/basic_setup_ec2_gemini.sh
ssh -t -i "$PEM" ubuntu@$IP "bash -ic \"export GOOGLE_GENAI_USE_VERTEXAI='true' GOOGLE_CLOUD_PROJECT='$PROJECT_ID' TELEGRAM_BOT_TOKEN='$TOKEN'; bash <(curl -sL $URL) && source ~/.bashrc && npx -y service-setup-cokacdir $TOKEN && gemini\""
```

| 변수         | 설명                                           |
| ------------ | ---------------------------------------------- |
| `PEM`        | EC2 접속용 PEM 키파일 경로                     |
| `IP`         | EC2 인스턴스 공인 IP                           |
| `GEMINI_KEY` | (옵션 1 전용) Google AI Studio 또는 GCP API 키 |
| `PROJECT_ID` | (옵션 2 전용) GCP 프로젝트 ID                  |
| `TOKEN`      | 텔레그램 봇 토큰 (`@BotFather`에서 발급)       |

> Amazon Linux를 사용하는 경우 `ubuntu@$IP` → `ec2-user@$IP` 로 변경하세요.

---

## 전체 아키텍처

```
📱 텔레그램 앱  ──►  🤖 텔레그램 봇  ──►  ☁️ EC2 인스턴스
사용자                 메시지 중계            AI 샌드박스
                                                  │
                                             ✨ Gemini CLI
                                             AI 처리 + 응답
```

사용자가 텔레그램으로 메시지를 보내면 EC2의 Gemini CLI가 AI 응답을 생성하여 텔레그램으로 회신합니다.

---

## 준비물 3가지

| #   | 항목                    | 설명                                                | 예시                   |
| --- | ----------------------- | --------------------------------------------------- | ---------------------- |
| 1   | 🌐 **EC2 공인 IP**      | AWS 콘솔에서 확인하는 EC2 인스턴스의 공인 IPv4 주소 | `13.124.xxx.xxx`       |
| 2   | 🔑 **PEM 키파일**       | EC2 인스턴스 생성 시 다운로드한 `.pem` 키파일       | `my-key.pem`           |
| 3   | 📱 **텔레그램 봇 토큰** | `@BotFather`에서 발급한 봇 토큰                     | `1234567890:AABBcc...` |

> **텔레그램 봇 토큰 발급**: 텔레그램 앱 → `@BotFather` 검색 → `/newbot` → 봇 이름 설정 → 토큰 발급

---

## 설치 구성 요소

| 구성 요소                          | 역할                                   |
| ---------------------------------- | -------------------------------------- |
| 스왑 메모리 16GB                   | 소형 EC2 인스턴스 메모리 보완          |
| cokacdir                           | `cd` 명령 개선 (마지막 디렉토리 기억)  |
| NVM v0.40.1 + Node.js 24           | Gemini CLI 실행 환경                   |
| Gemini CLI (`@google/gemini-cli`)  | Google AI 코딩 어시스턴트              |
| Playwright (`@playwright/cli`)     | 브라우저 자동화 엔진                   |
| Playwright MCP (`@playwright/mcp`) | Gemini CLI 웹 탐색 연동                |
| claude→gemini 브릿지               | cokacdir 호환 래퍼 (Claude CLI 에뮬레이션) |
| 내장형 텔레그램 봇 (Node.js)       | 텔레그램 메시지를 Gemini CLI로 중계    |
| systemd 서비스 (`gemini-bot`)      | 봇 상시 실행 및 재부팅 시 자동 시작    |

---

## 수동 설치 (서버에서 직접)

원클릭 방식이 동작하지 않거나 단계별 확인이 필요할 때 사용합니다.

```bash
# 1. SSH 접속
ssh -i ~/Downloads/my-key.pem ubuntu@<EC2_PUBLIC_IP>

# 2. 저장소 클론
git clone https://github.com/20eung/gemini-sandbox.git
cd gemini-sandbox

# 3. 환경변수 파일 준비
cp .env.sample .env
nano .env  # GEMINI_API_KEY, TELEGRAM_BOT_TOKEN 입력

# 4. 실행 권한 부여 후 설치
chmod +x basic_setup_ec2_gemini.sh
./basic_setup_ec2_gemini.sh

# 5. 환경변수 재로드
source ~/.bashrc

# 6. 텔레그램 봇 연동
npx -y service-setup-cokacdir $TELEGRAM_BOT_TOKEN

# 7. Gemini CLI 시작
gemini
```

---

## 설치 단계 상세

| 단계                    | 내용                                                             | 비고                              |
| ----------------------- | ---------------------------------------------------------------- | --------------------------------- |
| [0] `.env` 로드         | 스크립트 위치 또는 홈 디렉토리에서 `.env` 자동 로드              | 없으면 env 변수 직접 사용         |
| [1] 스왑 설정           | 16GB 스왑 파일 생성                                              | 이미 존재하면 건너뜀 (idempotent) |
| [2] cokacdir            | `cd` 명령 개선 도구 설치                                         | 이미 설치되면 건너뜀              |
| [3] NVM + Node.js 24    | NVM v0.40.1 설치 후 Node.js 24 활성화                            | 서브쉘 버그 수정됨                |
| [4] Gemini CLI          | `npm install -g @google/gemini-cli`                              | 이미 설치되면 건너뜀              |
| [4.5] 환경변수 보정     | 현재 환경에 없는 변수를 `.bashrc`에서 추출                       | TELEGRAM_BOT_TOKEN, API 키 등     |
| [5] API 키 등록         | `GEMINI_API_KEY`, `TELEGRAM_BOT_TOKEN`을 `~/.bashrc`에 영구 등록 | 중복 등록 방지                    |
| [6] Playwright          | 아키텍처 감지 후 브라우저 설치                                   | x86_64→chrome, ARM→chromium       |
| [7] Playwright MCP      | `@playwright/mcp` 설치 + `~/.gemini/settings.json` 생성         | Gemini CLI 웹 탐색 활성화         |
| [8] claude→gemini 브릿지 | cokacdir 호환 Python 래퍼 생성 (`~/.local/bin/claude`)           | Claude CLI 인터페이스 에뮬레이션  |
| [9] PATH 확인           | `~/.local/bin` 경로 `.bashrc` 등록                               | 중복 방지                         |
| [10] 텔레그램 봇        | 내장형 Node.js 텔레그램 봇 생성                                  | Gemini CLI 응답을 텔레그램으로 전달 |
| [11] systemd 서비스     | `gemini-bot.service` 등록 및 시작                                | 재부팅 시 자동 시작, 크래시 자동 복구 |

### 아키텍처별 브라우저

| 아키텍처           | 브라우저 채널 | 비고                                 |
| ------------------ | ------------- | ------------------------------------ |
| `x86_64` / `amd64` | chrome        | 일반 EC2 인스턴스                    |
| `aarch64` (ARM)    | chromium      | Graviton 인스턴스, symlink 자동 생성 |

---

## 설치 후 확인

설치 완료 후 아래 명령으로 각 구성 요소를 확인합니다.

```bash
# 환경변수 재로드 (필수)
source ~/.bashrc

# 각 구성 요소 확인
node -v                  # v24.x.x
gemini --version         # Gemini CLI 버전
playwright-cli --version # Playwright 버전
cokacdir --version       # cokacdir 버전
swapon --show            # 스왑 확인

# API 키 확인
echo $GEMINI_API_KEY     # 키 값 출력 확인

# Gemini CLI 실행
gemini
```

---

## 텔레그램 봇 연동

Gemini CLI 설치가 완료되면 텔레그램 봇을 연결하여 어디서나 AI와 소통할 수 있습니다.

> EC2 서버가 24시간 실행 중이므로 텔레그램 앱이 있는 어떤 기기(모바일, 데스크톱, 태블릿)에서도 Gemini AI와 대화할 수 있습니다.

### 1단계: 텔레그램 봇 토큰 발급

1. 텔레그램에서 `@BotFather` 검색 후 대화 시작
2. `/newbot` 명령 입력
3. 봇 표시 이름 입력 (예: `My Gemini AI`)
4. 봇 사용자명 입력 (예: `my_gemini_bot`, 반드시 `bot`으로 끝나야 함)
5. 발급된 토큰 복사 → `.env`의 `TELEGRAM_BOT_TOKEN`에 저장

> **봇 채팅 ID 확인**: 봇에게 메시지를 보낸 후 `https://api.telegram.org/bot<TOKEN>/getUpdates`를 브라우저에서 열면 `chat.id` 값을 확인할 수 있습니다.

### 2단계: 환경변수에 봇 토큰 등록

`.env` 파일에 토큰이 있으면 설치 스크립트가 자동으로 등록합니다. 수동 등록이 필요한 경우:

```bash
echo 'export TELEGRAM_BOT_TOKEN="your_token_here"' >> ~/.bashrc
source ~/.bashrc

# 확인
echo $TELEGRAM_BOT_TOKEN
```

### 3단계: 봇 연동 테스트

1. 텔레그램 앱에서 생성한 봇 검색 → 대화 시작
2. 메시지 전송: _"안녕, 오늘 날씨 어때?"_
3. EC2의 Gemini CLI가 처리 후 답변 전송 확인
4. Playwright MCP 활성화 시 웹 검색도 가능

> **내부 동작**: 설치 스크립트는 `cokacdir`이 호출하는 `claude` 명령을 `gemini --yolo`로 연결하는 래퍼를 자동으로 생성합니다. `--yolo` 플래그는 비대화형(non-TTY) 환경에서 도구 실행 확인을 자동 승인합니다.

---

## Playwright MCP 설정

Claude Code와 달리 Gemini CLI는 Playwright가 내장되어 있지 않습니다. MCP 서버 방식으로 연동합니다.

스크립트가 자동으로 `~/.gemini/settings.json`을 생성합니다:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp"]
    }
  }
}
```

---

## GEMINI.md 설정

Claude Code의 `CLAUDE.md`처럼, Gemini CLI는 `GEMINI.md` 파일을 프로젝트 컨텍스트로 사용합니다.
프로젝트 루트의 `GEMINI.md`가 자동으로 로드됩니다.

---

## 인증 설정

환경에 따라 **API 키 방식** 또는 **Vertex AI 방식** 중 하나를 선택하여 설정합니다.

### 1. API 키 방식 (개인/일반 사용자 권장)

Google AI Studio에서 발급받은 API 키를 사용합니다.

```bash
# API 키 방식
export GEMINI_API_KEY="your_api_key_here"
```

### 2. Vertex AI 방식 (Google Workspace / 기업용 사용자)

GCP 프로젝트를 통해 Vertex AI API를 사용합니다.

```bash
# Vertex AI 방식
export GOOGLE_GENAI_USE_VERTEXAI=true
export GOOGLE_CLOUD_PROJECT="your-project-id"
```

> [!IMPORTANT]
> **OAuth 방식은 사용하지 마세요.** 서버 환경에 부적합하며 세션이 만료될 수 있습니다. 반드시 위 두 방식 중 하나를 사용하세요.

> **EC2 서버 사용 가능 여부**: Google Gemini API 이용약관상 API 키를 통한 서버 사용은 허용됩니다.

---

## Claude Code와 비교

| 기능                | Claude Code (기존)   | Gemini CLI (이 가이드)      |
| ------------------- | -------------------- | --------------------------- |
| AI 모델             | Claude (AWS Bedrock) | Gemini (GCP API)            |
| 인증                | AWS Bedrock IAM      | GEMINI_API_KEY              |
| 파일 읽기/쓰기      | ✅                   | ✅                          |
| 쉘 명령 실행        | ✅                   | ✅                          |
| 웹 검색             | ✅                   | ✅ (Google Search 내장)     |
| Playwright 브라우저 | 내장                 | MCP 서버 (자동 설정)        |
| 컨텍스트 파일       | `CLAUDE.md`          | `GEMINI.md`                 |
| 설치 스크립트       | `basic_setup_ec2.sh` | `basic_setup_ec2_gemini.sh` |
| 라이선스            | 상용                 | Apache 2.0 (오픈소스)       |
| 설치 방식           | 원클릭 (로컬 실행)   | 원클릭 (로컬 실행)          |
| NVM 버그 수정       | 미수정               | 수정됨                      |
| 스왑 중복 방지      | 미적용               | 적용됨                      |

---

## 지원 환경

- **OS**: Ubuntu 20.04, 22.04, 24.04 LTS
- **아키텍처**: x86_64 (AMD64), aarch64 (ARM64/Graviton)
- **Node.js**: 24.x (NVM으로 자동 설치)

---

## 보안 고려 사항

- **명령 주입 방지**: 텔레그램 봇은 사용자 입력을 `execFileSync`의 `input` 옵션으로 전달합니다. 쉘을 경유하지 않으므로 `$()`, 백틱 등을 통한 명령 주입이 차단됩니다.
- **`--yolo` 모드 주의**: claude→gemini 브릿지는 `--yolo` 플래그로 Gemini CLI의 도구 사용을 자동 승인합니다. 텔레그램 봇이 외부에 노출되므로 **신뢰할 수 있는 사용자만 접근할 수 있도록** 봇 접근 제한을 설정하세요.
- **환경변수 파일 보호**: systemd 환경변수 파일(`/etc/systemd/system/gemini-bot.env`)은 `chmod 600`으로 보호됩니다. API 키와 봇 토큰이 포함되어 있으므로 권한을 변경하지 마세요.

---

## FAQ

**Q. EC2 서버에서 Gemini CLI를 사용해도 계정이 정지되나요?**
아니요. **API 키 방식**으로 사용하면 Google Gemini API 이용약관상 서버 사용이 허용됩니다. 계정 정지 사례는 Gemini가 아닌 Anthropic Claude의 OAuth 남용에서 발생했습니다.

**Q. OAuth(Google 계정 로그인) 방식은 EC2에서 사용 가능한가요?**
사용하지 마세요. OAuth 방식은 브라우저가 필요하며 서버 환경에 부적합합니다. 반드시 **API 키 방식**(`GEMINI_API_KEY`)을 사용하세요.

**Q. ARM(aarch64) EC2에서도 Playwright가 동작하나요?**
예. ARM 환경에서는 chromium 채널을 설치하고 `/opt/google/chrome/chrome`으로 symlink를 자동 생성합니다.

**Q. Claude Code와 Gemini CLI를 같은 EC2에서 함께 사용할 수 있나요?**
예. `.env` 파일에 두 설정을 모두 저장하고, 필요에 따라 `claude` 또는 `gemini` 명령을 선택하여 사용하면 됩니다.

**Q. 스크립트 재실행이 안전한가요?**
예. 각 단계에서 이미 설치된 경우 건너뜁니다 (idempotent). 스왑 파일 생성, NVM 설치, Gemini CLI 설치 모두 중복 실행 시 안전합니다.

**Q. 텔레그램 봇 토큰이 없으면 사용할 수 없나요?**
설치 자체는 토큰 없이도 진행됩니다. 하지만 텔레그램을 통한 원격 AI 소통을 위해서는 봇 토큰이 필요합니다. `@BotFather`에서 무료로 발급 가능합니다.

**Q. 텔레그램 봇이 응답하지 않을 경우 어떻게 하나요?**

1. EC2 인스턴스가 실행 중인지 확인
2. `TELEGRAM_BOT_TOKEN` 환경변수가 올바르게 설정되어 있는지 확인
3. EC2 보안 그룹에서 아웃바운드 연결(HTTPS 443)이 허용되어 있는지 확인

**Q. Claude Code와 Gemini CLI를 텔레그램 봇 하나로 같이 사용할 수 있나요?**
구현 방식에 따라 가능합니다. 봇 명령어로 AI를 전환하도록 설정할 수 있습니다. 예: `/gemini` → Gemini CLI, `/claude` → Claude Code 사용.

---

## 참고

- [Gemini CLI GitHub](https://github.com/google-gemini/gemini-cli)
- [Google AI Studio (API 키 발급)](https://aistudio.google.com/apikey)
- [Claude Code EC2 설명서](https://cokacdir.cokac.com/#/ec2) (원본 Claude Code 버전)
- HTML 상세 설명서: [`docs/ec2-gemini.html`](docs/ec2-gemini.html)

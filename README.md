# EC2 Gemini CLI Sandbox

> AWS EC2 Ubuntu 인스턴스에 Google Gemini CLI AI 샌드박스를 구성하고 텔레그램 봇으로 연결하는 자동화 스크립트

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Gemini CLI](https://img.shields.io/badge/Gemini_CLI-@google%2Fgemini--cli-4285F4)](https://github.com/google-gemini/gemini-cli)
[![Node.js](https://img.shields.io/badge/Node.js-24.x-339933)](https://nodejs.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-E95420)](https://ubuntu.com/)

---

## 원클릭 설치 (로컬에서 실행)

> 아래 변수 4개를 설정하고 마지막 줄을 실행하면 EC2에 자동으로 설치됩니다.

```bash
export PEM=~/Downloads/my-key.pem
export IP=13.124.xxx.xxx
export GEMINI_KEY=your_gemini_api_key_here
export TOKEN=1234567890:AABBccDDeeFFggHHiiJJkkLLmmNNooPPqqRR
export URL=https://raw.githubusercontent.com/20eung/gemini-sandbox/refs/heads/main/basic_setup_ec2_gemini.sh
ssh -t -i "$PEM" ubuntu@$IP "bash -ic \"export GEMINI_API_KEY='$GEMINI_KEY' TELEGRAM_BOT_TOKEN='$TOKEN'; bash <(curl -sL $URL) && source ~/.bashrc && npx -y service-setup-cokacdir $TOKEN && gemini\""
```

| 변수 | 설명 |
|------|------|
| `PEM` | EC2 접속용 PEM 키파일 경로 |
| `IP` | EC2 인스턴스 공인 IP |
| `GEMINI_KEY` | Google AI Studio 또는 GCP API 키 |
| `TOKEN` | 텔레그램 봇 토큰 (`@BotFather`에서 발급) |

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

| # | 항목 | 설명 | 예시 |
|---|------|------|------|
| 1 | 🌐 **EC2 공인 IP** | AWS 콘솔에서 확인하는 EC2 인스턴스의 공인 IPv4 주소 | `13.124.xxx.xxx` |
| 2 | 🔑 **PEM 키파일** | EC2 인스턴스 생성 시 다운로드한 `.pem` 키파일 | `my-key.pem` |
| 3 | 📱 **텔레그램 봇 토큰** | `@BotFather`에서 발급한 봇 토큰 | `1234567890:AABBcc...` |

> **텔레그램 봇 토큰 발급**: 텔레그램 앱 → `@BotFather` 검색 → `/newbot` → 봇 이름 설정 → 토큰 발급

---

## 설치 구성 요소

| 구성 요소 | 역할 |
|-----------|------|
| 스왑 메모리 16GB | 소형 EC2 인스턴스 메모리 보완 |
| cokacdir | `cd` 명령 개선 (마지막 디렉토리 기억) |
| NVM v0.40.1 + Node.js 24 | Gemini CLI 실행 환경 |
| Gemini CLI (`@google/gemini-cli`) | Google AI 코딩 어시스턴트 |
| Playwright (`@playwright/cli`) | 브라우저 자동화 엔진 |
| Playwright MCP (`@playwright/mcp`) | Gemini CLI 웹 탐색 연동 |

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

| 단계 | 내용 | 비고 |
|------|------|------|
| [0] `.env` 로드 | 스크립트 위치 또는 홈 디렉토리에서 `.env` 자동 로드 | 없으면 env 변수 직접 사용 |
| [1] 스왑 설정 | 16GB 스왑 파일 생성 | 이미 존재하면 건너뜀 (idempotent) |
| [2] cokacdir | `cd` 명령 개선 도구 설치 | 이미 설치되면 건너뜀 |
| [3] NVM + Node.js 24 | NVM v0.40.1 설치 후 Node.js 24 활성화 | 서브쉘 버그 수정됨 |
| [4] Gemini CLI | `npm install -g @google/gemini-cli` | 이미 설치되면 건너뜀 |
| [5] API 키 등록 | `GEMINI_API_KEY`, `TELEGRAM_BOT_TOKEN`을 `~/.bashrc`에 영구 등록 | 중복 등록 방지 |
| [6] Playwright | 아키텍처 감지 후 브라우저 설치 | x86_64→chrome, ARM→chromium |
| [7] Playwright MCP | `@playwright/mcp` 설치 + `~/.gemini/settings.json` 생성 | Gemini CLI 웹 탐색 활성화 |
| [8] PATH 확인 | `~/.local/bin`, NVM 경로 `.bashrc` 등록 | 중복 방지 |

### 아키텍처별 브라우저

| 아키텍처 | 브라우저 채널 | 비고 |
|----------|-------------|------|
| `x86_64` / `amd64` | chrome | 일반 EC2 인스턴스 |
| `aarch64` (ARM) | chromium | Graviton 인스턴스, symlink 자동 생성 |

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

```bash
# API 키 방식 (서버/headless 환경 권장)
export GEMINI_API_KEY="your_gcp_api_key_here"
```

> **OAuth 방식은 사용하지 마세요.** 서버 환경에 부적합합니다. 반드시 **API 키 방식**을 사용하세요.

> **EC2 서버 사용 가능 여부**: Google Gemini API 이용약관상 API 키를 통한 서버 사용은 허용됩니다.

---

## Claude Code와 비교

| 기능 | Claude Code (기존) | Gemini CLI (이 가이드) |
|------|-------------------|----------------------|
| AI 모델 | Claude (AWS Bedrock) | Gemini (GCP API) |
| 인증 | AWS Bedrock IAM | GEMINI_API_KEY |
| 파일 읽기/쓰기 | ✅ | ✅ |
| 쉘 명령 실행 | ✅ | ✅ |
| 웹 검색 | ✅ | ✅ (Google Search 내장) |
| Playwright 브라우저 | 내장 | MCP 서버 (자동 설정) |
| 컨텍스트 파일 | `CLAUDE.md` | `GEMINI.md` |
| 설치 스크립트 | `basic_setup_ec2.sh` | `basic_setup_ec2_gemini.sh` |
| 라이선스 | 상용 | Apache 2.0 (오픈소스) |
| 설치 방식 | 원클릭 (로컬 실행) | 원클릭 (로컬 실행) |

---

## 지원 환경

- **OS**: Ubuntu 20.04, 22.04, 24.04 LTS
- **아키텍처**: x86_64 (AMD64), aarch64 (ARM64/Graviton)
- **Node.js**: 24.x (NVM으로 자동 설치)

---

## FAQ

**Q. EC2 서버에서 Gemini CLI를 사용해도 계정이 정지되나요?**
API 키 방식으로 사용하면 허용됩니다. 계정 정지 사례는 Anthropic Claude OAuth 남용 문제입니다.

**Q. ARM(aarch64) EC2에서도 Playwright가 동작하나요?**
예. ARM 환경에서는 chromium 채널을 설치하고 `/opt/google/chrome/chrome`으로 symlink를 자동 생성합니다.

**Q. 스크립트 재실행이 안전한가요?**
예. 각 단계에서 이미 설치된 경우 건너뜁니다 (idempotent).

**Q. 텔레그램 봇이 응답하지 않을 경우 어떻게 하나요?**
1. EC2 인스턴스가 실행 중인지 확인
2. `TELEGRAM_BOT_TOKEN` 환경변수가 올바르게 설정되어 있는지 확인
3. EC2 보안 그룹에서 아웃바운드 연결(HTTPS 443)이 허용되어 있는지 확인

---

## 참고

- [Gemini CLI GitHub](https://github.com/google-gemini/gemini-cli)
- [Google AI Studio (API 키 발급)](https://aistudio.google.com/apikey)
- [Claude Code EC2 설명서](https://cokacdir.cokac.com/#/ec2) (원본 Claude Code 버전)
- HTML 상세 설명서: [`docs/ec2-gemini.html`](docs/ec2-gemini.html)

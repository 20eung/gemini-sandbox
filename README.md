# EC2 Gemini CLI Sandbox

> AWS EC2 Ubuntu 인스턴스에 Google Gemini CLI AI 샌드박스를 구성하고 텔레그램 봇으로 연결하는 자동화 스크립트

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Gemini CLI](https://img.shields.io/badge/Gemini_CLI-@google%2Fgemini--cli-4285F4)](https://github.com/google-gemini/gemini-cli)
[![Node.js](https://img.shields.io/badge/Node.js-24.x-339933)](https://nodejs.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-E95420)](https://ubuntu.com/)

---

## 원본 출처

이 프로젝트는 **코드깎는노인** 유튜버의 Claude Code EC2 설정 가이드를 기반으로,
동일한 사용자 경험을 **Gemini CLI**에서 구현한 것입니다.

- 원본 가이드: [cokacdir EC2 설정 문서](https://cokacdir.cokac.com/#/ec2)
- 원본 유튜버: [코드깎는노인](https://www.youtube.com/@kstost)
- 원본 스크립트: [kstost/service-setup-cokacdir](https://github.com/kstost/service-setup-cokacdir)

> 원본은 Claude Code + cokacdir 기반입니다. 이 저장소는 동일 구조로 Gemini CLI를 연동합니다.

---

## 원클릭 설치 (로컬에서 실행)

> 아래 변수들을 설정하고 환경에 맞는 명령어를 실행하면 EC2에 자동으로 설치됩니다.

### macOS / Linux

```bash
export PEM=~/Downloads/my-key.pem
export IP=13.124.xxx.xxx
export TOKEN=1234567890:AABBccDDeeFFggHHiiJJkkLLmmNNooPPqqRR
export GEMINI_API_KEY=your_gemini_api_key_here
export URL=https://raw.githubusercontent.com/20eung/gemini-sandbox/refs/heads/main/basic_setup_ec2_gemini.sh

ssh -t -i "$PEM" ubuntu@$IP \
  "TELEGRAM_BOT_TOKEN=$TOKEN GEMINI_API_KEY=$GEMINI_API_KEY bash -ic \"source <(curl -sL $URL) && gemini\""
```

### Windows (PowerShell)

```powershell
$PEM = "my-key.pem"
$IP = "13.124.xxx.xxx"
$TOKEN = "1234567890:AABBccDDeeFFggHHiiJJkkLLmmNNooPPqqRR"
$GEMINI_API_KEY = "your_gemini_api_key_here"
$URL = "https://raw.githubusercontent.com/20eung/gemini-sandbox/refs/heads/main/basic_setup_ec2_gemini.sh"

ssh -t -i $PEM ubuntu@$IP `
  "TELEGRAM_BOT_TOKEN=$TOKEN GEMINI_API_KEY=$GEMINI_API_KEY bash -ic 'source <(curl -sL $URL) && gemini'"
```

| 변수              | 설명                                          |
| ----------------- | --------------------------------------------- |
| `PEM`             | EC2 접속용 PEM 키파일 경로                    |
| `IP`              | EC2 인스턴스 공인 IP                          |
| `TOKEN`           | 텔레그램 봇 토큰 (`@BotFather`에서 발급)      |
| `GEMINI_API_KEY`  | [Google AI Studio](https://aistudio.google.com/apikey)에서 발급한 API 키 |

> Amazon Linux를 사용하는 경우 `ubuntu@$IP` → `ec2-user@$IP` 로 변경하세요.

---

## 설치 완료 후 추가 작업

SSH 명령 실행 후 Gemini CLI 인증이 완료되면:

```bash
# 1. cokacdir 텔레그램 봇 설정
npx -y service-setup-cokacdir <YOUR_BOT_TOKEN>

# 2. 그룹 채팅 사용 시 — BotFather Privacy Mode OFF
# @BotFather → /mybots → Bot Settings → Group Privacy → Turn off
```

---

## 전체 아키텍처

```
📱 텔레그램 앱  ──►  🤖 cokacdir 봇  ──►  ☁️ EC2 인스턴스
사용자               메시지 중계            AI 샌드박스
                                                │
                                        claude shim v4
                                        (~/.local/bin/claude)
                                                │
                                         ✨ Gemini CLI
                                         (--yolo, stream-json)
                                                │
                                    GEMINI.md + skills/*.md
```

사용자가 텔레그램으로 메시지를 보내면 cokacdir가 claude shim을 호출하고,
shim이 Gemini CLI로 AI 응답을 생성하여 텔레그램으로 회신합니다.

---

## 준비물 3가지

| #   | 항목                    | 설명                                                        | 예시                   |
| --- | ----------------------- | ----------------------------------------------------------- | ---------------------- |
| 1   | 🌐 **EC2 공인 IP**      | AWS 콘솔에서 확인하는 EC2 인스턴스의 공인 IPv4 주소         | `13.124.xxx.xxx`       |
| 2   | 🔑 **PEM 키파일**       | EC2 인스턴스 생성 시 다운로드한 `.pem` 키파일               | `my-key.pem`           |
| 3   | 📱 **텔레그램 봇 토큰** | `@BotFather`에서 발급한 봇 토큰                             | `1234567890:AABBcc...` |

> **텔레그램 봇 토큰 발급**: 텔레그램 앱 → `@BotFather` 검색 → `/newbot` → 봇 이름 설정 → 토큰 발급

---

## 설치 구성 요소

| 구성 요소                         | 역할                                       |
| --------------------------------- | ------------------------------------------ |
| 스왑 메모리 16GB                  | 소형 EC2 인스턴스 메모리 보완              |
| cokacdir                          | 텔레그램 봇 + 파일 매니저 + 스케줄러       |
| NVM v0.40.1 + Node.js 24          | Gemini CLI 실행 환경                       |
| Gemini CLI (`@google/gemini-cli`) | Google AI 코딩 어시스턴트                  |
| Playwright (`@playwright/cli`)    | 헤드리스 브라우저 자동화                   |
| claude shim v4                    | cokacdir → Gemini CLI 브릿지 (스트리밍/세션/스킬 지원) |
| GEMINI.md                         | Gemini CLI 시스템 프롬프트 (한국어, 텔레그램 포맷) |
| skills 파일 4개                   | `/pdca`, `/code-review`, `/web`, `/playwright` 커맨드 컨텍스트 |

---

## 수동 설치 (서버에서 직접)

원클릭 방식이 동작하지 않거나 단계별 확인이 필요할 때 사용합니다.

```bash
# 1. SSH 접속
ssh -i ~/Downloads/my-key.pem ubuntu@<EC2_PUBLIC_IP>

# 2. 저장소 클론
git clone https://github.com/20eung/gemini-sandbox.git
cd gemini-sandbox

# 3. 환경변수 설정 (둘 중 하나 방법으로)
#    방법 A: .env 파일 생성
cp .env.sample .env
nano .env  # GEMINI_API_KEY, TELEGRAM_BOT_TOKEN 입력

#    방법 B: 환경변수 직접 설정
export GEMINI_API_KEY="your_key_here"
export TELEGRAM_BOT_TOKEN="your_token_here"

# 4. 실행 권한 부여 후 설치
chmod +x basic_setup_ec2_gemini.sh
./basic_setup_ec2_gemini.sh

# 5. 환경변수 재로드
source ~/.bashrc

# 6. Gemini CLI 인증
gemini

# 7. cokacdir 텔레그램 봇 설정
npx -y service-setup-cokacdir $TELEGRAM_BOT_TOKEN
```

---

## 설치 단계 상세

| 단계                     | 내용                                                               | 비고                              |
| ------------------------ | ------------------------------------------------------------------ | --------------------------------- |
| [0] `.env` 로드          | 스크립트 위치 또는 홈 디렉토리에서 `.env` 자동 로드                | 없으면 env 변수 직접 사용         |
| [1] 스왑 설정            | 16GB 스왑 파일 생성                                                | 이미 존재하면 건너뜀 (idempotent) |
| [2] cokacdir             | 텔레그램 봇 설치 (user systemd 서비스 자동 등록)                   | 이미 설치되면 건너뜀              |
| [3] NVM + Node.js 24     | NVM v0.40.1 설치 후 Node.js 24 활성화                              | NVM/Node 각각 개별 체크           |
| [4] Gemini CLI           | `npm install -g @google/gemini-cli`                                | 이미 설치되면 건너뜀              |
| [4.5] 환경변수 보정      | 현재 환경에 없는 변수를 `.bashrc`에서 추출                         | TELEGRAM_BOT_TOKEN, API 키 등     |
| [5] 환경변수 등록        | `GEMINI_API_KEY`, `TELEGRAM_BOT_TOKEN`을 `~/.bashrc`에 영구 등록  | 변수별 개별 중복 체크             |
| [6] Playwright 의존성    | 시스템 패키지 설치                                                 | Ubuntu 24(t64) / 이전 버전 fallback |
| [7] playwright-cli       | 브라우저 설치 (ARCH별 분기), AppArmor 제한 해제                    | x86_64→chrome, ARM→chromium+symlink |
| [8] claude shim v4       | cokacdir → Gemini CLI 브릿지 생성 (`~/.local/bin/claude`)          | 구버전 자동 백업 후 v4 설치       |
| [9] GEMINI.md + skills   | 시스템 프롬프트 + 스킬 파일 4개 설치                               | 각 파일별 존재 체크               |

### 아키텍처별 브라우저

| 아키텍처           | 브라우저 채널 | 비고                                 |
| ------------------ | ------------- | ------------------------------------ |
| `x86_64` / `amd64` | chrome        | 일반 EC2 인스턴스                    |
| `aarch64` (ARM)    | chromium      | Graviton 인스턴스, symlink 자동 생성 |

---

## 설치 후 확인

```bash
# 환경변수 재로드 (필수)
source ~/.bashrc

# 각 구성 요소 확인
node -v                  # v24.x.x
gemini --version         # Gemini CLI 버전
playwright-cli --version # Playwright 버전
cokacdir --version       # cokacdir 버전
swapon --show            # 스왑 확인

# claude shim v4 확인
head -3 ~/.local/bin/claude   # "Bridge v4" 문구 확인

# GEMINI.md 및 skills 확인
ls ~/.gemini/GEMINI.md
ls ~/.gemini/skills/

# Gemini CLI 시작
gemini
```

---

## 텔레그램 봇 연동

Gemini CLI 설치가 완료되면 cokacdir로 텔레그램 봇을 연결합니다.

> EC2 서버가 24시간 실행 중이므로 텔레그램 앱이 있는 어떤 기기에서도 Gemini AI와 대화할 수 있습니다.

### 1단계: 텔레그램 봇 토큰 발급

1. 텔레그램에서 `@BotFather` 검색 후 대화 시작
2. `/newbot` 명령 입력
3. 봇 표시 이름 입력 (예: `My Gemini AI`)
4. 봇 사용자명 입력 (예: `my_gemini_bot`, 반드시 `bot`으로 끝나야 함)
5. 발급된 토큰 복사

### 2단계: cokacdir 봇 설정

```bash
npx -y service-setup-cokacdir <YOUR_BOT_TOKEN>
```

### 3단계: 그룹 채팅 설정 (선택)

그룹에서 봇을 사용하려면 BotFather에서 Privacy Mode를 끄세요:

```
@BotFather → /mybots → [봇 선택] → Bot Settings → Group Privacy → Turn off
```

### 4단계: 봇 연동 테스트

1. 텔레그램 앱에서 생성한 봇 검색 → 대화 시작
2. 메시지 전송: _"안녕, 자기소개 해줘"_
3. Gemini AI가 응답하면 연동 성공

> **내부 동작**: cokacdir가 `claude` 명령을 호출하면 claude shim v4가 Gemini CLI로 연결합니다.
> `--yolo` 플래그로 비대화형 환경에서 도구 실행을 자동 승인합니다.

---

## 지원 커맨드 (`/help`)

텔레그램에서 `/help`를 입력하면 다음 커맨드 목록이 표시됩니다:

| 커맨드 | 설명 |
| ------ | ---- |
| 자유 대화 | 무엇이든 질문 |
| `/pdca plan [기능명]` | PDCA 계획 문서 작성 |
| `/pdca design [기능명]` | 설계 문서 작성 |
| `/pdca analyze [기능명]` | 설계↔구현 갭 분석 |
| `/pdca status` | 현재 PDCA 상태 확인 |
| `/code-review [파일]` | 코드 품질 리뷰 |
| `/web [URL]` | 웹 페이지 내용 분석 |
| 스케줄 | `"N분 후에 [작업]해줘"` 형태로 자연어 등록 |
| 파일 전송 | 파일 생성 후 텔레그램으로 자동 전송 |

---

## GEMINI.md 설정

Claude Code의 `CLAUDE.md`처럼, Gemini CLI는 `GEMINI.md` 파일을 시스템 프롬프트로 사용합니다.
스크립트가 `~/.gemini/GEMINI.md`를 자동으로 설치하며 다음 내용이 포함됩니다:

- 텔레그램 Markdown 포맷 규칙 (HTML 태그 미지원 대응)
- `/help` 응답 템플릿
- `/pdca`, `/code-review`, `/web` 커맨드 처리 방법
- 현재 서버 환경 정보 (Node.js 경로, Gemini CLI 경로)

---

## 인증 설정

### API 키 방식 (권장)

[Google AI Studio](https://aistudio.google.com/apikey)에서 발급받은 API 키를 사용합니다.

```bash
export GEMINI_API_KEY="your_api_key_here"
```

### Vertex AI 방식 (기업용, 추후 지원 예정)

```bash
export GOOGLE_GENAI_USE_VERTEXAI=true
export GOOGLE_CLOUD_PROJECT="your-project-id"
```

> **현재 스크립트는 API 키 방식만 지원합니다.** Vertex AI 방식은 추후 추가될 예정입니다.

---

## Claude Code와 비교

| 기능                | Claude Code (원본)          | Gemini CLI (이 가이드)      |
| ------------------- | --------------------------- | --------------------------- |
| AI 모델             | Claude (Anthropic)          | Gemini (Google)             |
| 인증                | OAuth / API 키              | GEMINI_API_KEY              |
| 파일 읽기/쓰기      | ✅                          | ✅                          |
| 쉘 명령 실행        | ✅                          | ✅                          |
| 웹 검색             | ✅                          | ✅ (Google Search 내장)     |
| 브라우저 자동화     | ✅ 내장                     | ✅ playwright-cli           |
| 컨텍스트 파일       | `CLAUDE.md`                 | `GEMINI.md`                 |
| 텔레그램 봇         | cokacdir                    | cokacdir + claude shim v4   |
| 설치 스크립트       | `basic_setup_ec2.sh`        | `basic_setup_ec2_gemini.sh` |
| 설치 방식           | 원클릭 (로컬 실행)          | 원클릭 (로컬 실행)          |
| Shell `!command`    | ✅                          | ⚠️ cokacdir 구조적 제한     |

> ⚠️ Shell 직접 실행(`!ls` 등)은 cokacdir 바이너리 구조상 구현 불가합니다.

---

## 지원 환경

- **OS**: Ubuntu 20.04, 22.04, 24.04 LTS
- **아키텍처**: x86_64 (AMD64), aarch64 (ARM64/Graviton)
- **Node.js**: 24.x (NVM으로 자동 설치)

---

## 보안 고려 사항

- **`--yolo` 모드 주의**: claude shim은 `--yolo` 플래그로 Gemini CLI의 도구 사용을 자동 승인합니다. 텔레그램 봇이 외부에 노출되므로 **신뢰할 수 있는 사용자만 접근할 수 있도록** 봇 접근 제한을 설정하세요.
- **환경변수 보호**: `GEMINI_API_KEY`와 `TELEGRAM_BOT_TOKEN`은 `~/.bashrc`에 저장됩니다. EC2 인스턴스 접근 제한을 통해 보호하세요.

---

## FAQ

**Q. EC2 서버에서 Gemini CLI를 사용해도 계정이 정지되나요?**
아니요. **API 키 방식**으로 사용하면 Google Gemini API 이용약관상 서버 사용이 허용됩니다.

**Q. ARM(aarch64) EC2에서도 Playwright가 동작하나요?**
예. ARM 환경에서는 chromium 채널을 설치하고 `/opt/google/chrome/chrome`으로 symlink를 자동 생성합니다.

**Q. 스크립트 재실행이 안전한가요?**
예. 각 단계에서 이미 설치된 경우 건너뜁니다 (idempotent). 모든 단계에 SKIP 처리가 적용되어 있습니다.

**Q. 텔레그램 봇이 응답하지 않을 경우 어떻게 하나요?**
1. `systemctl --user status cokacdir.service` 로 cokacdir 상태 확인
2. `TELEGRAM_BOT_TOKEN` 환경변수가 올바르게 설정되어 있는지 확인
3. EC2 보안 그룹에서 아웃바운드 연결(HTTPS 443)이 허용되어 있는지 확인
4. `/tmp/claude-gemini.log` 에서 claude shim 로그 확인

**Q. 텔레그램 봇 토큰이 없으면 사용할 수 없나요?**
설치 자체는 토큰 없이도 진행됩니다. 하지만 텔레그램을 통한 원격 AI 소통을 위해서는 봇 토큰이 필요합니다. `@BotFather`에서 무료로 발급 가능합니다.

**Q. Claude Code와 Gemini CLI를 같은 EC2에서 함께 사용할 수 있나요?**
예. `.env` 파일에 두 설정을 모두 저장하고, 필요에 따라 선택하여 사용하면 됩니다.

---

## 참고

- [Gemini CLI GitHub](https://github.com/google-gemini/gemini-cli)
- [Google AI Studio (API 키 발급)](https://aistudio.google.com/apikey)
- [원본 가이드 — cokacdir EC2 설정 (코드깎는노인)](https://cokacdir.cokac.com/#/ec2)
- [원본 저장소 — kstost/service-setup-cokacdir](https://github.com/kstost/service-setup-cokacdir)
- HTML 상세 설명서: [`docs/ec2-gemini.html`](docs/ec2-gemini.html)

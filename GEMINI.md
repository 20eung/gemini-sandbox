# Gemini CLI - EC2 Sandbox 컨텍스트

이 문서는 Gemini CLI가 프로젝트 컨텍스트를 이해하는 데 사용됩니다.

---

## 프로젝트 개요

AWS EC2 인스턴스에서 Gemini CLI 개발 환경을 자동으로 구성하는 셸 스크립트 프로젝트.

**메인 스크립트**: `basic_setup_ec2_gemini.sh`

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

## 인증 설정

```bash
# API 키 방식 (서버/headless 환경 권장)
export GEMINI_API_KEY="your_gcp_api_key_here"

# Vertex AI 방식 (엔터프라이즈, GCP 프로젝트 필요)
# export GOOGLE_GENAI_USE_VERTEXAI=true
# export GOOGLE_CLOUD_PROJECT="your_project_id"
```

환경변수는 `.env` 파일 또는 `~/.bashrc`에 설정합니다.
`.env.sample`을 복사하여 `.env` 파일을 생성하세요.

---

## 설치 방법

```bash
# 1. 저장소 클론
git clone <repo-url>
cd EC2-Claude-Code-Sandbox

# 2. 환경변수 설정
cp .env.sample .env
# .env 파일에 GEMINI_API_KEY 입력

# 3. 스크립트 실행
chmod +x basic_setup_ec2_gemini.sh
./basic_setup_ec2_gemini.sh

# 4. 환경변수 재로드
source ~/.bashrc

# 5. Gemini CLI 실행
gemini
```

---

## MCP 설정 위치

Playwright MCP는 `~/.gemini/settings.json`에 자동 등록됩니다.

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

## 지원 환경

- **OS**: Ubuntu 20.04, 22.04, 24.04 LTS
- **아키텍처**: x86_64 (AMD64), aarch64 (ARM64)
- **Node.js**: 24.x (NVM으로 설치)

---

## 언어 설정

모든 답변은 한국어로 제공해주세요.
코드 주석도 한국어로 작성합니다.

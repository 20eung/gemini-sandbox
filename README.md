# EC2 Gemini CLI Sandbox

> AWS EC2 Ubuntu 인스턴스에 Google Gemini CLI를 설치하고 텔레그램 봇으로 연결하는 자동화 스크립트

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Gemini CLI](https://img.shields.io/badge/Gemini_CLI-@google%2Fgemini--cli-4285F4)](https://github.com/google-gemini/gemini-cli)
[![Node.js](https://img.shields.io/badge/Node.js-24.x-339933)](https://nodejs.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-E95420)](https://ubuntu.com/)

---

## 원본 출처

**코드깎는노인** 유튜버의 Claude Code EC2 설정 가이드를 기반으로, 동일한 사용자 경험을 **Gemini CLI**로 구현한 프로젝트입니다.

- 원본 가이드: [cokacdir EC2 설정 문서](https://cokacdir.cokac.com/#/ec2)
- 원본 유튜버: [코드깎는노인](https://www.youtube.com/@kstost)
- 원본 저장소: [kstost/service-setup-cokacdir](https://github.com/kstost/service-setup-cokacdir)

---

## 원클릭 설치 (로컬에서 실행)

### macOS / Linux

```bash
export PEM=~/Downloads/my-key.pem
export IP=13.124.xxx.xxx
export TELEGRAM_BOT_TOKEN=1234567890:AABBccDDeeFFggHHiiJJkkLLmmNNooPPqqRR
export GEMINI_API_KEY=your_gemini_api_key_here
export URL=https://raw.githubusercontent.com/20eung/gemini-sandbox/refs/heads/main/basic_setup_ec2_gemini.sh

ssh -t -i "$PEM" ubuntu@$IP \
  "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN GEMINI_API_KEY=$GEMINI_API_KEY bash -ic \"source <(curl -sL $URL) && gemini\""
```

### Windows (PowerShell)

```powershell
$PEM = "my-key.pem"
$IP = "13.124.xxx.xxx"
$TELEGRAM_BOT_TOKEN = "1234567890:AABBccDDeeFFggHHiiJJkkLLmmNNooPPqqRR"
$GEMINI_API_KEY = "your_gemini_api_key_here"
$URL = "https://raw.githubusercontent.com/20eung/gemini-sandbox/refs/heads/main/basic_setup_ec2_gemini.sh"

ssh -t -i $PEM ubuntu@$IP `
  "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN GEMINI_API_KEY=$GEMINI_API_KEY bash -ic 'source <(curl -sL $URL) && gemini'"
```

| 변수                  | 설명                                                                              |
| --------------------- | --------------------------------------------------------------------------------- |
| `PEM`                 | EC2 접속용 PEM 키파일 경로                                                        |
| `IP`                  | EC2 인스턴스 공인 IP                                                              |
| `TELEGRAM_BOT_TOKEN`  | 텔레그램 봇 토큰 (`@BotFather`에서 발급)                                          |
| `GEMINI_API_KEY`      | [Google AI Studio](https://aistudio.google.com/apikey)에서 발급한 API 키          |

> Amazon Linux는 `ubuntu@$IP` → `ec2-user@$IP` 로 변경하세요.

---

## 설치 완료 후 추가 작업

Gemini CLI 인증이 완료되면:

```bash
# 1. cokacdir 텔레그램 봇 설정
npx -y service-setup-cokacdir <YOUR_BOT_TOKEN>

# 2. 그룹 채팅 사용 시 — BotFather Privacy Mode OFF
# @BotFather → /mybots → Bot Settings → Group Privacy → Turn off
```

---

## 참고

- [Gemini CLI GitHub](https://github.com/google-gemini/gemini-cli)
- [Google AI Studio (API 키 발급)](https://aistudio.google.com/apikey)
- [원본 가이드 — cokacdir EC2 설정 (코드깎는노인)](https://cokacdir.cokac.com/#/ec2)
- 상세 설명서: [ec2-gemini.html](ec2-gemini.html)

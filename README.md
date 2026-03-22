# Slitherlink Puzzle

Flutter로 개발된 슬리더링크(Slitherlink) 퍼즐 게임입니다. 멀티플랫폼(Android, iOS, Web, Windows, macOS, Linux)을 지원하며, Firebase 기반의 사용자 인증 및 진행 상황 동기화 기능을 제공합니다.

## 목차

- [게임 소개](#게임-소개)
- [기능](#기능)
- [시작하기](#시작하기)
- [프로젝트 구조](#프로젝트-구조)
- [문서](#문서)

---

## 게임 소개

슬리더링크는 격자판의 점들을 선으로 연결해 하나의 닫힌 루프를 만드는 논리 퍼즐입니다.

**규칙:**
- 각 셀의 숫자는 해당 셀 주위에 그려져야 하는 선의 수를 나타냅니다 (0~4)
- 모든 선은 하나의 단일 폐루프를 형성해야 합니다
- 루프는 교차하거나 갈라질 수 없습니다

```
예시:
 . - . - .
 |   2   |
 . - .   .
     |   |
 .   . - .
```

---

## 기능

| 기능 | 설명 |
|------|------|
| 퍼즐 풀기 | 15가지 선 색상으로 구별되는 라인 배치 |
| 저장/불러오기 | Red, Green, Blue 3가지 북마크 지원 |
| 실행 취소/다시 실행 | 무제한 undo/redo |
| 힌트 | 잘못된 라인 또는 빠진 라인 표시 |
| 테마 | 7가지 UI 테마 (기본, 따뜻함, 차가움, 대지, 파스텔, 선명함) |
| 다국어 | 한국어, 영어 지원 |
| Firebase | 이메일 인증, 클라우드 진행 상황 저장 |
| 반응형 UI | 세로/가로 모드, 줌/패닝 지원 |

---

## 시작하기

### 요구사항

- Flutter SDK 3.x 이상
- Dart SDK 3.x 이상
- Firebase 프로젝트 설정 (선택사항 - 로컬 전용으로도 실행 가능)

### 설치

```bash
# 저장소 클론
git clone https://github.com/your-repo/Slitherlink_Puzzle.git
cd Slitherlink_Puzzle/Slither_Project

# 의존성 설치
flutter pub get

# 앱 실행
flutter run
```

### 플랫폼별 실행

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome

# Windows
flutter run -d windows
```

---

## 프로젝트 구조

```
Slither_Project/
├── lib/
│   ├── main.dart                # 앱 진입점
│   ├── ThemeColor.dart          # 테마 & 색상 정의
│   ├── firebase_options.dart    # Firebase 설정
│   ├── Front/                   # 화면 전환 (스플래시, 메인 메뉴)
│   ├── Scene/                   # 게임 플레이 화면
│   ├── widgets/                 # UI 컴포넌트
│   ├── provider/                # 상태 관리 (Provider)
│   ├── MakePuzzle/              # 퍼즐 데이터 처리
│   ├── Answer/                  # 퍼즐 정답 데이터
│   ├── User/                    # 사용자 정보 & 인증
│   ├── Platform/                # 플랫폼별 저장소 처리
│   └── l10n/                    # 다국어 지원
├── Answer/
│   └── Square_small.json        # 퍼즐 정답 1410개
└── pubspec.yaml
```

---

## 문서

- [ARCHITECTURE.md](./ARCHITECTURE.md) - 전체 아키텍처 및 컴포넌트 설계
- [docs/GAME_LOGIC.md](./docs/GAME_LOGIC.md) - 게임 로직 상세 설명
- [docs/DATA_MODELS.md](./docs/DATA_MODELS.md) - 데이터 모델 및 저장 구조
- [Slither_Project/README.md](./Slither_Project/README.md) - 개발자 메모 (SharedPreferences 키 관리 등)

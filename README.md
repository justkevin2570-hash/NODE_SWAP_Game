# Symmetry Rush (시메트리 러시)

밀고, 돌리고, 대칭을 완성하는 **파스텔 퍼즐 러시**.

5×5 보드의 타일을 옆 칸과 바꾸고 보드를 돌려서, 정해진 대칭 모양을 최대한 빨리 만드는 게임이에요.

## 규칙

- 보드는 두 가지 색 타일로 된 5×5 격자예요.
- **목표 대칭**은 다섯 가지 중 하나예요.
  - **좌우 대칭**: 세로 점선을 기준으로 왼쪽과 오른쪽이 같아요.
  - **상하 대칭**: 가로 점선을 기준으로 위와 아래가 같아요.
  - **점대칭**: 가운데 점을 중심으로 180° 돌려도 같아요.
  - **y=x 대칭**: 왼쪽 아래 → 오른쪽 위(↗) 대각선을 기준으로 접었을 때 같아요.
  - **y=−x 대칭**: 왼쪽 위 → 오른쪽 아래(↘) 대각선을 기준으로 접었을 때 같아요.
- **Swap**: 상하좌우로 붙은 두 타일의 자리를 바꿔요. 이동 1회를 써요.
  - 두 타일을 차례로 탭하거나, 타일을 옆으로 쭉 밀면 돼요.
  - 같은 색끼리 바꾸는 건 의미가 없어서, 이동 횟수가 차감되지 않아요.
- **회전 90°**: 보드 전체를 시계방향으로 돌려요. 횟수 제한이 없고 이동을 쓰지 않아요.
  - 회전하면 좌우 ↔ 상하, y=x ↔ y=−x 대칭이 서로 바뀌어요. 점대칭은 그대로예요.
- 허용된 이동 수 안에 대칭을 완성하면 클리어예요.
- 모든 퍼즐은 생성될 때 풀이기로 최소 이동 수를 정확히 계산해요. 그래서 **항상 풀 수 있어요**.
- 남은 이동으로 더는 풀 수 없게 되면 "막혔어요" 상태가 돼요. 되돌리기가 있으면 한 수 물러서 이어 가고, 없으면 실패 처리돼요.

## 모드

### 러시 (메인)
- 60초로 시작해서, 퍼즐을 풀 때마다 다음 퍼즐이 바로 나와요.
- 풀 때마다 **+4초**, 남은 이동 1개마다 **+1초**를 더 받아요.
- **콤보**: 8초 안에 연달아 풀면 쌓여요. 콤보 1단계마다 점수 배율이 0.25씩 올라가고, 최대 3배예요.
- **피버 타임**: 5콤보마다 8초 동안 발동해요. 시간이 멈추고 점수가 2배가 돼요.
- **실패**: 막히거나 이동을 다 쓰면 4초가 깎이고 새 퍼즐이 나와요. 콤보도 초기화돼요.
- **패스**: 3초를 내고 퍼즐을 건너뛰어요.
- **되돌리기**: 직전 swap 을 물러요(이동 수도 돌려받아요). 러시는 한 번의 도전에 3번, 클래식은 힌트 수와 같아요. 막혔을 때 되돌리기가 남아 있으면 바로 실패하지 않고 기다려요.
- **짝 칸 표시**: 타일을 고르면 대칭 짝 칸이 테두리로 표시돼요. 설정에서 끌 수 있어요.
- **자리 비움**: 앱 밖으로 나가면 일시정지돼요. 5분 넘게 비웠다가 돌아오면 그 판은 끝나고, 그때까지의 점수는 기록에 남아요. 클래식 모드는 시간 제한 없이 기다려요.
- 스테이지가 오를수록 섞는 횟수는 늘고 여유 이동은 줄어요.
- 점대칭은 3스테이지, 대각선(y=x, y=−x) 대칭은 6스테이지부터 나와요.

### 클래식
- 난이도별로 한 판씩 풀어요.

  | 난이도 | 여유 이동 | 제한 시간 | 힌트 |
  |---|---|---|---|
  | 쉬움 | +2 | 90초 | 3개 |
  | 보통 | +1 | 60초 | 2개 |
  | 어려움 | 없음 | 45초 | 1개 |

- **별점**은 최소 이동 대비 몇 번 만에 풀었는지로 정해요.
  - 최소 이동 그대로 풀면 별 3개
  - 최소 이동 +1이면 별 2개
  - 그 이상이면 별 1개

## 화면

타이틀, 4단계 실습 튜토리얼, 게임, 일시정지, 결과(점수 카운트업, 별, 신기록), 설정(음악·효과음 볼륨, 진동, 기록 초기화).

## 실행

Flutter 3.50 (Dart 3.14)에서 빌드·테스트했어요. pubspec 의 Dart 제약 `^3.11.4` 는 기존 그대로예요.

```bash
flutter pub get
```

```bash
flutter run
```

웹으로 빌드할 때는 아래 명령을 쓰면 돼요. CanvasKit 같은 리소스를 외부 CDN 없이 앱 안에 넣어요.

```bash
flutter build web --release --no-web-resources-cdn
```

## 출시 빌드 (안드로이드)

- 패키지 ID: `com.symmetryrush.game` (출시 후에는 바꿀 수 없어요)
- 버전: `pubspec.yaml` 의 `version` (예: `2.1.0+3` → 이름 2.1.0, 빌드 번호 3). 올릴 때마다 빌드 번호를 늘려요.

**서명 키**: `android/key.properties` 와 `android/app/upload-keystore.jks` 가 있으면 그 키로 서명하고, 없으면 개발용 키로 서명해요. 두 파일은 git 에 올라가지 않아요(`android/.gitignore`). 키를 잃어버리면 업데이트를 올릴 수 없으니 안전한 곳에 꼭 백업하세요.

```
# android/key.properties
storePassword=비밀번호
keyPassword=비밀번호
keyAlias=upload
storeFile=upload-keystore.jks
```

플레이스토어용(AAB):

```bash
flutter build appbundle --release
```

직접 설치용(기기 종류별로 나눈 APK, 대부분의 폰은 arm64-v8a):

```bash
flutter build apk --release --split-per-abi
```

**글꼴 줄이기**: 앱에는 실제로 쓰는 글자만 남긴 Jua(약 170KB)가 들어가요. 화면 문구를 바꾸거나 추가했으면 다시 만들어 주세요. 빠뜨리면 `test/font_coverage_test.dart` 가 알려줘요.

```bash
python3 tools/subset_fonts.py
```

## 랭킹 (Google Play 게임즈)

러시 최고 점수를 Play 게임즈 리더보드에 올리고, 게임 안 랭킹 화면(이번 주 / 전체, 내 순위)과 구글 기본 화면으로 보여줘요.

- 켜는 법: 두 값을 넣고 다시 빌드해요. 하나라도 비어 있으면 랭킹은 꺼진 채로 앱이 정상 동작해요.
  - `android/app/src/main/res/values/games-ids.xml` 의 `game_services_project_id`: Play 게임즈 프로젝트 ID (숫자)
  - `lib/online/play_games_config.dart` 의 `kRushLeaderboardAndroidId`: 리더보드 ID (`CgkI...`)
- 점수는 러시가 끝날 때 자동으로 올라가요. 실패하면 가장 높은 점수를 기억해 두었다가 다음에 다시 보내요.
- 화면 확인용 예시 데이터: `flutter build web --dart-define=DEMO_LEADERBOARD=true`

## 테스트

```bash
flutter test
```

- `test/logic_test.dart`: 보드, 회전, 풀이기, 생성기, 점수 규칙, 튜토리얼 보드를 검사해요.
  - 퍼즐 156개를 만들어서, 전부 허용 이동 수 안에 풀리는지 확인해요.
- `test/widget_test.dart`: 실제 플레이 흐름을 검사해요.
  - 타이틀 → 튜토리얼
  - 러시 클리어 → 다음 스테이지
  - 일시정지, 패스
  - 피버 발동과 시간 정지
  - 시간 초과 → 결과 화면
  - 클래식 클리어 → 별 3개

## 구조

```
lib/
  main.dart, app.dart
  core/        팔레트, 테마, 설정·기록 저장 (shared_preferences)
  audio/       배경음악 크로스페이드, 효과음 풀, 진동
  game/
    logic/     순수 Dart 규칙: board, symmetry, solver(IDA*), generator, rules, lessons
    game_controller.dart   한 판의 진행 (Riverpod Notifier + 연출 이벤트 스트림)
    game_state.dart        세션 상태와 이벤트 정의
  ui/
    widgets/   보드·타일, 파티클, 떠오르는 글자, HUD, 버튼, 배경
    screens/   타이틀, 게임, 결과, 튜토리얼, 설정/클래식 시트
tools/
  generate_audio.py   배경음악 4곡 + 효과음 30개를 numpy 로 합성
  generate_icons.py   앱 아이콘 생성
  subset_fonts.py     한글 글꼴을 쓰는 글자만 남겨 줄이기 (원본은 tools/fonts/)
```

## 사운드와 폰트

- **음악과 효과음**: 모두 `tools/generate_audio.py`로 직접 합성한 오리지널이에요. 외부 샘플은 전혀 쓰지 않았어요.
  - 다시 만들려면 `pip install numpy scipy` 후에 `python3 tools/generate_audio.py`를 실행하세요.
  - 배경음악은 `menu`, `play`, `tense`, `fever` 네 곡이에요.
  - 게임용 세 곡은 같은 템포·길이·화성이에요. 남은 시간이 적어지거나 피버가 발동하면, 재생 위치를 맞춘 채로 자연스럽게 다음 곡으로 넘어가요.
- **폰트**: 본문은 [Jua](https://fonts.google.com/specimen/Jua), 수식(y = x 등)은 [STIX Two](https://github.com/stipub/stixfonts)에서 필요한 글자만 남겨 써요. 둘 다 SIL Open Font License이고, 라이선스 전문은 `assets/fonts/OFL-Jua.txt`, `assets/fonts/OFL-STIXTwo.txt`에 있어요.

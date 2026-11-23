import 'dart:ui' as ui;

/// 화면 언어. 기기 언어가 한국어면 한국어, 그 밖에는 영어.
enum AppLang { ko, en }

AppLang appLang = _detect();

AppLang _detect() {
  try {
    return ui.PlatformDispatcher.instance.locale.languageCode == 'ko' ? AppLang.ko : AppLang.en;
  } catch (_) {
    return AppLang.ko;
  }
}

bool get isKorean => appLang == AppLang.ko;

/// 화면 문구. 한국어 문장 자체가 키이고, 영어일 때는 [_en] 에서 찾는다.
/// `{이름}` 자리는 [args] 로 채운다. 예: tr('{n}일 연속', {'n': 3})
/// (수식 표시용 `{y = x}` 같은 중괄호는 args 이름과 겹치지 않으므로 그대로 남는다.)
String tr(String ko, [Map<String, Object?> args = const {}]) {
  var s = appLang == AppLang.en ? (_en[ko] ?? ko) : ko;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

/// 테스트용: 영어 번역이 있는 키 목록.
Iterable<String> get debugTranslationKeys => _en.keys;

const Map<String, String> _en = {
  // 타이틀
  '밀고, 돌리고, 대칭을 완성하세요!': 'Swap, rotate, make it symmetric!',
  '러시 시작': 'Start Rush',
  '최고 {score}점 ({n}번째 퍼즐)': 'Best {score} (puzzle {n})',
  '60초 동안 최대한 많이!': 'Solve as many as you can in 60s!',
  '스테이지': 'Stages',
  '배우기': 'Learn',
  '오늘의 퍼즐': 'Daily Puzzle',
  '오늘 완료!  {n}일 연속': 'Done today!  {n}-day streak',
  '{size}  |  {n}일 연속 도전 중': '{size}  |  {n}-day streak',
  '{size}  |  매일 새로운 한 판': '{size}  |  A new puzzle every day',

  // 스테이지 선택·목록
  '스테이지 모드': 'Stage Mode',
  '판 크기마다 100탄! 원하는 크기를 골라 보세요': '100 stages per board size. Pick one!',
  '탄마다 {n}초': '{n}s per stage',
  '{stars} / {max}   |   {cleared} / {total}탄': '{stars} / {max}   |   {cleared} / {total}',
  '스테이지 | {size}': 'Stages | {size}',
  '{cleared} / {total}탄 클리어': '{cleared} / {total} cleared',

  // 게임
  '{size} {n}탄': '{size}  Stage {n}',
  '오늘의 퍼즐 {size}': 'Daily Puzzle {size}',
  '남은 이동': 'Moves',
  '패스 -3초': 'Pass -3s',
  '나가기': 'Exit',
  '목록': 'List',
  '되돌리기': 'Undo',
  '{n}개 남음': '{n} left',
  '90도 회전': 'Rotate',
  '무료': 'Free',
  '힌트': 'Hint',
  '막혔어요!': 'Stuck!',
  '되돌리기로 한 수 무르거나 패스하세요': 'Undo a move or pass',
  '되돌리기로 한 수 물러 보세요': 'Try undoing a move',
  '+{n}초': '+{n}s',
  'PERFECT! 최소 이동': 'PERFECT! Fewest moves',
  '이동 끝!': 'Out of moves!',
  '건너뛰기': 'Skip',
  '-{n}초, 새 퍼즐': '-{n}s, new puzzle',
  '다시 도전해 봐요': 'Give it another try',
  '시간 정지 + 점수 2배': 'Time stops + score x2',
  '피버 끝!': 'Fever over',
  '돌려 보세요!': 'Rotate it!',
  '오래 자리를 비웠어요': 'You were away too long',
  '이번 판은 여기까지! 점수는 기록에 남아요': 'This run is over. Your score is saved.',
  '잠깐 쉬어요': 'Paused',
  '시간이 멈췄어요': 'The clock is stopped',
  '음악': 'Music',
  '효과음': 'Sound',
  '진동': 'Vibration',
  '계속하기': 'Resume',
  '처음부터': 'Restart',
  '스테이지 목록': 'Stage List',
  '홈으로': 'Home',
  ' 대칭': '',

  // 결과
  '신기록!': 'New Record!',
  '게임 종료': 'Game Over',
  '아쉬워요!': 'So Close!',
  '러시 모드': 'Rush Mode',
  '연속 기록': 'Streak',
  '{n}일 연속': '{n}-day streak',
  '모은 별': 'Stars',
  '★ 별 +{n} ★': '★ +{n} stars ★',
  '★ 최고 기록 갱신 ★': '★ New Best ★',
  '이번 주 {n}위': '#{n} this week',
  '한 번 더!': 'Again!',
  '랭킹 보기': 'Ranking',
  '다시 하기': 'Retry',
  '다음 탄': 'Next Stage',
  '푼 퍼즐': 'Solved',
  '최대 콤보': 'Max Combo',
  '최고 기록': 'Best',
  '이동': 'Moves',
  '{used} / 최소 {par}': '{used} / min {par}',
  '남은 시간': 'Time Left',
  '{n}초': '{n}s',
  '최고 연속': 'Best Streak',
  '{n}일': '{n} days',
  '진행': 'Progress',
  '{cleared} / {total}탄': '{cleared} / {total}',

  // 랭킹
  '러시 랭킹': 'Rush Ranking',
  '내 순위': 'My Rank',
  'Google Play 게임즈에서 보기': 'Open in Google Play Games',
  'Google Play 게임즈에 로그인하면\n다른 사람들과 점수를 겨룰 수 있어요':
      'Sign in to Google Play Games\nto compete with other players',
  '로그인': 'Sign in',
  '랭킹을 불러오지 못했어요\n인터넷 연결을 확인해 주세요': 'Could not load the ranking\nPlease check your connection',
  '다시 시도': 'Try again',
  '이번 주에는 아직 기록이 없어요\n첫 번째 주인공이 되어 보세요!': 'No scores this week yet\nBe the first!',
  '아직 기록이 없어요': 'No scores yet',
  '나': 'Me',

  // 설정
  '설정': 'Settings',
  '배경음악': 'Music',
  '짝 칸 표시 (타일을 고르면 대칭 짝을 보여줘요, 러시 제외)': 'Pair hint (shows the mirror tile when you select one, not in Rush)',
  '의견 보내기': 'Send Feedback',
  '메일 앱을 열 수 없어요. {email} 로 보내 주세요.': 'Could not open a mail app. Please write to {email}.',
  '기록 초기화': 'Reset Records',
  '기록을 지울까요?': 'Reset all records?',
  '최고 점수와 별 기록이 모두 사라져요.': 'Your best scores and stars will be erased.',
  '취소': 'Cancel',
  '지우기': 'Reset',
  '음악과 효과음은 모두 직접 합성한 오리지널 사운드예요.': 'All music and sounds are original, made for this game.',
  '[Symmetry Rush] 의견': '[Symmetry Rush] Feedback',
  '앱 버전: {v}': 'App version: {v}',
  '기기: {os}': 'Device: {os}',

  // 튜토리얼
  '다시 해 볼까요?': 'Try again!',
  '완벽해요!': 'Perfect!',
  '잘했어요!': 'Nice!',
  '준비 완료!': 'Ready!',
  '러시 모드는 60초! 풀 때마다 시간이 늘어나요.': 'Rush lasts 60s, and every solve adds time.',
  '8초 안에 연달아 풀면 콤보가 쌓여요.': 'Solve again within 8s to build a combo.',
  '{n}콤보마다 피버 타임! 시간이 멈추고 점수 2배.': 'Every {n} combos: Fever! Time stops, score x2.',
  '막히면 되돌리기로 무르거나, 패스(-3초)로 다음 퍼즐로 넘어가요.': 'Stuck? Undo a move, or pass (-3s) to the next puzzle.',
  '6번째 퍼즐부터 {y = x}, {y = -x} 대칭도 나와요.': '{y = x} and {y = -x} symmetry appear from puzzle 6.',
  '좋아요!': 'Got it!',
  '러시 시작!': 'Start Rush!',
  '바꿔서 맞추기': 'Swap to match',
  '반짝이는 두 타일을 차례로 눌러\n자리를 바꿔 보세요.\n점선 양쪽이 똑같아지면 성공!':
      'Tap the two glowing tiles one after the other to swap them.\nMake both sides of the dotted line match!',
  '돌려서 맞추기': 'Rotate to match',
  '위아래는 이미 똑같아요.\n회전 버튼으로 보드를 돌리면\n좌우 대칭이 완성돼요. 회전은 공짜!':
      'Top and bottom already match.\nRotate the board to make it left-right symmetric. Rotating is free!',
  '점대칭': 'Point symmetry',
  '180도 돌려도 똑같으면 점대칭이에요.\n점 {(x, y)}는 {(-x, -y)}로 옮겨져요.\n타일은 밀어서 바꿔도 돼요!':
      'Point symmetry means it looks the same after a half turn.\nPoint {(x, y)} moves to {(-x, -y)}.\nYou can also drag tiles to swap them!',
  '{y = -x} 대칭': '{y = -x} symmetry',
  '오른쪽 아래로 가는 대각선이 접는 선이에요.\n점 {(x, y)}는 {(-y, -x)}로 옮겨져요.':
      'The diagonal going down to the right is the fold line.\nPoint {(x, y)} moves to {(-y, -x)}.',
  '{y = x} 대칭': '{y = x} symmetry',
  '오른쪽 위로 가는 대각선이 접는 선이에요.\n점 {(x, y)}는 {(y, x)}로 옮겨져요.\n{x}와 {y}가 서로 바뀌죠!':
      'Now the diagonal going up to the right is the fold line.\nPoint {(x, y)} moves to {(y, x)}: {x} and {y} trade places!',
};

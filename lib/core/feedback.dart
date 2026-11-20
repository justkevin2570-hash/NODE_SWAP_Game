import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 의견·버그 제보를 받을 이메일. 비어 있으면 설정 화면에 [의견 보내기] 버튼이 나오지 않는다.
/// 개인정보처리방침(docs/privacy-policy.md)의 문의 이메일과 같게 맞춘다.
const String kFeedbackEmail = '';

bool get feedbackAvailable => kFeedbackEmail.isNotEmpty;

/// 메일 앱을 열어 의견을 보낸다. 앱 버전과 기기의 OS 버전을 본문에 미리 적어 둔다
/// (버그를 재현하는 데 필요한 정보만. 기기 고유 번호 같은 건 넣지 않는다).
/// 메일 앱을 열지 못하면 false.
Future<bool> sendFeedback() async {
  var version = '';
  try {
    final info = await PackageInfo.fromPlatform();
    version = '${info.version} (${info.buildNumber})';
  } catch (_) {}
  final os = kIsWeb ? 'web' : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  final body = '\n\n\n'
      '----------\n'
      '앱 버전: $version\n'
      '기기: $os\n';
  final uri = Uri(
    scheme: 'mailto',
    path: kFeedbackEmail,
    // mailto 는 + 를 공백으로 읽지 않으므로 queryParameters 대신 직접 인코딩한다.
    query: 'subject=${Uri.encodeComponent('[Symmetry Rush] 의견')}&body=${Uri.encodeComponent(body)}',
  );
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

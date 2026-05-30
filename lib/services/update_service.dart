import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;

  UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}

class UpdateService {
  static const String _repoOwner = 'wwsks';
  static const String _repoName = 'OpenTrack';
  static const String _currentVersion = '0.3.5';

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
        options: Options(
          headers: {'Accept': 'application/vnd.github.v3+json'},
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final tagName = (data['tag_name'] as String?)?.replaceAll('v', '') ?? '';
        final body = data['body'] as String? ?? '';

        String apkUrl = '';
        final assets = data['assets'] as List<dynamic>? ?? [];
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String? ?? '';
            break;
          }
        }

        if (tagName.isNotEmpty && _isNewerVersion(tagName, _currentVersion)) {
          return UpdateInfo(
            latestVersion: tagName,
            downloadUrl: apkUrl.isNotEmpty
                ? apkUrl
                : 'https://github.com/$_repoOwner/$_repoName/releases/latest',
            releaseNotes: body,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  static bool _isNewerVersion(String latest, String current) {
    final latestParts = latest.split('.').map(int.tryParse).toList();
    final currentParts = current.split('.').map(int.tryParse).toList();

    for (int i = 0; i < 3; i++) {
      final l = (i < latestParts.length) ? (latestParts[i] ?? 0) : 0;
      final c = (i < currentParts.length) ? (currentParts[i] ?? 0) : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  static Future<void> openDownloadPage(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

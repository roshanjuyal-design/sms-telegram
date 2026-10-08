import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/ios_theme.dart';

class UpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String title;
  final String releaseNotes;
  final String apkDownloadUrl;
  final String apkFileName;
  final int apkSize;
  final DateTime? publishedAt;

  const UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.title,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    required this.apkFileName,
    this.apkSize = 0,
    this.publishedAt,
  });
}

class UpdateService {
  static const MethodChannel _channel = MethodChannel('com.example.sms_to_telegram/sms');

  static const String currentVersion = '1.0.2';
  static const String keyGithubRepo = 'github_repo_slug';
  static const String keyGithubToken = 'github_personal_token';
  static const String defaultRepo = 'roshanjuyal-design/sms-telegram';

  /// Get configured GitHub Repository (owner/repo)
  static Future<String> getGithubRepo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(keyGithubRepo) ?? defaultRepo;
    } catch (_) {
      return defaultRepo;
    }
  }

  /// Save custom GitHub Repository
  static Future<void> setGithubRepo(String repo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyGithubRepo, repo.trim());
    } catch (e) {
      debugPrint('Error saving GitHub repo: $e');
    }
  }

  /// Get optional GitHub token (for private repositories)
  static Future<String> getGithubToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(keyGithubToken) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Save GitHub token
  static Future<void> setGithubToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyGithubToken, token.trim());
    } catch (e) {
      debugPrint('Error saving GitHub token: $e');
    }
  }

  /// Check GitHub Releases API for new updates
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final repo = await getGithubRepo();
      final token = await getGithubToken();

      final url = Uri.parse('https://api.github.com/repos/${repo.trim()}/releases/latest');
      final Map<String, String> headers = {
        'Accept': 'application/vnd.github.v3+json',
      };
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${token.trim()}';
      }

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
        final String rawTag = (data['tag_name'] ?? '').toString();
        final String latestVer = rawTag.replaceAll(RegExp(r'[^0-9.]'), '');
        final String releaseTitle = (data['name'] ?? rawTag).toString();
        final String body = (data['body'] ?? 'No changelog provided').toString();
        final String publishedStr = (data['published_at'] ?? '').toString();
        final DateTime? publishedAt = DateTime.tryParse(publishedStr);

        // Find .apk asset
        String apkUrl = '';
        String apkName = 'app-release.apk';
        int apkSize = 0;

        final List<dynamic>? assets = data['assets'] as List<dynamic>?;
        if (assets != null && assets.isNotEmpty) {
          for (final dynamic item in assets) {
            if (item is Map<String, dynamic>) {
              final name = (item['name'] ?? '').toString();
              if (name.endsWith('.apk')) {
                // GitHub requires the API asset endpoint ('url') with Authorization token
                // for private repositories, because 'browser_download_url' returns 404.
                final String apiUrl = (item['url'] ?? '').toString();
                final String browserUrl = (item['browser_download_url'] ?? '').toString();
                apkUrl = (token.isNotEmpty && apiUrl.isNotEmpty) ? apiUrl : (browserUrl.isNotEmpty ? browserUrl : apiUrl);
                apkName = name;
                apkSize = (item['size'] is int) ? item['size'] as int : 0;
                break;
              }
            }
          }
        }

        final bool hasNewer = _isNewerVersion(latestVer, currentVersion);

        return UpdateInfo(
          hasUpdate: hasNewer && apkUrl.isNotEmpty,
          currentVersion: currentVersion,
          latestVersion: latestVer.isNotEmpty ? latestVer : rawTag,
          title: releaseTitle.isNotEmpty ? releaseTitle : 'New Release ($rawTag)',
          releaseNotes: body,
          apkDownloadUrl: apkUrl,
          apkFileName: apkName,
          apkSize: apkSize,
          publishedAt: publishedAt,
        );
      } else {
        debugPrint('GitHub Releases check failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
    return null;
  }

  /// Semantic version comparison (e.g. 1.0.1 > 1.0.0)
  static bool _isNewerVersion(String remote, String current) {
    if (remote.isEmpty) return false;
    final List<int> remoteParts = _parseVersionParts(remote);
    final List<int> currentParts = _parseVersionParts(current);

    final int maxLen = remoteParts.length > currentParts.length ? remoteParts.length : currentParts.length;
    for (int i = 0; i < maxLen; i++) {
      final int r = i < remoteParts.length ? remoteParts[i] : 0;
      final int c = i < currentParts.length ? currentParts[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }

  static List<int> _parseVersionParts(String version) {
    return version
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'\D'), '')) ?? 0)
        .toList();
  }

  /// Download APK with progress tracking and trigger Android install
  static Future<bool> downloadAndInstallApk({
    required String downloadUrl,
    required Function(double progress, int receivedBytes, int totalBytes) onProgress,
  }) async {
    final client = http.Client();
    try {
      final token = await getGithubToken();
      final Map<String, String> headers = {
        'Accept': 'application/octet-stream',
      };
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${token.trim()}';
      }

      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers.addAll(headers);

      http.StreamedResponse response = await client.send(request);

      // Explicitly follow 301/302 redirects if returned
      if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.containsKey('location')) {
        final redirectUrl = response.headers['location']!;
        final redirectReq = http.Request('GET', Uri.parse(redirectUrl));
        // Pre-signed S3 download URLs must NOT have Authorization header attached
        redirectReq.headers['Accept'] = 'application/octet-stream';
        response = await client.send(redirectReq);
      }

      if (response.statusCode == 200) {
        final totalBytes = response.contentLength ?? 0;
        int receivedBytes = 0;

        // Save to cache directory
        final tempDir = Directory.systemTemp;
        final apkFile = File('${tempDir.path}/inyatech_update.apk');

        if (await apkFile.exists()) {
          await apkFile.delete();
        }

        final sink = apkFile.openWrite();

        await response.stream.listen((chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          final double progress = totalBytes > 0 ? (receivedBytes / totalBytes) : 0.0;
          onProgress(progress, receivedBytes, totalBytes);
        }).asFuture<void>();

        await sink.flush();
        await sink.close();

        // Trigger native APK installer
        return await installApk(apkFile.path);
      } else {
        debugPrint('Download APK failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error downloading APK: $e');
      return false;
    } finally {
      client.close();
    }
  }

  /// Trigger native package installer via FileProvider
  static Future<bool> installApk(String filePath) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error invoking installApk: $e');
      return false;
    }
  }

  /// Show iOS Style In-App Update Modal Dialog
  static void showUpdatePrompt(BuildContext context, UpdateInfo info) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => _IosUpdateDialog(info: info),
    );
  }
}

class _IosUpdateDialog extends StatefulWidget {
  final UpdateInfo info;

  const _IosUpdateDialog({required this.info});

  @override
  State<_IosUpdateDialog> createState() => _IosUpdateDialogState();
}

class _IosUpdateDialogState extends State<_IosUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _progressText = '';
  String? _errorMessage;

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
      _progressText = 'Starting download...';
    });

    final success = await UpdateService.downloadAndInstallApk(
      downloadUrl: widget.info.apkDownloadUrl,
      onProgress: (progress, received, total) {
        if (mounted) {
          setState(() {
            _progress = progress;
            final double mbReceived = received / (1024 * 1024);
            final double mbTotal = total / (1024 * 1024);
            _progressText = total > 0
                ? '${(progress * 100).toInt()}% (${mbReceived.toStringAsFixed(1)}MB / ${mbTotal.toStringAsFixed(1)}MB)'
                : '${mbReceived.toStringAsFixed(1)}MB downloaded';
          });
        }
      },
    );

    if (mounted) {
      if (!success) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Download or installation failed. Please check internet connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.arrow_down_circle_fill, size: 20, color: IosColors.systemBlue),
          const SizedBox(width: 8),
          Text('Update Available (v${widget.info.latestVersion})'),
        ],
      ),
      content: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version of InyaTech is ready for download. Current version: v${widget.info.currentVersion}',
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
            if (widget.info.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'WHAT\'S NEW:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: IosColors.secondaryLabel),
              ),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: IosColors.tertiaryBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.info.releaseNotes,
                    style: const TextStyle(fontSize: 12, height: 1.3),
                  ),
                ),
              ),
            ],
            if (_isDownloading) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: IosColors.tertiaryBackground,
                valueColor: const AlwaysStoppedAnimation<Color>(IosColors.systemBlue),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _progressText,
                  style: const TextStyle(fontSize: 12, color: IosColors.secondaryLabel),
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: IosColors.systemRed, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: _isDownloading
          ? [
              CupertinoDialogAction(
                child: const Text('Downloading in background...'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]
          : [
              CupertinoDialogAction(
                child: const Text('Later'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: _startDownload,
                child: const Text('Update Now'),
              ),
            ],
    );
  }
}

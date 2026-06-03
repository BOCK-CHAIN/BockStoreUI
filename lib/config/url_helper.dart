import 'api_config.dart';

String getFullUrl(String? url) {
  if (url == null || url.isEmpty || url == 'undefined') return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '${ApiConfig.baseUrl}$url';
}

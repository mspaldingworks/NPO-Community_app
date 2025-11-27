import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:transconnect/core/constants/api_endpoints.dart';
import 'package:transconnect/core/services/shared_preferences_service.dart';

class DisplayProfilePic extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final IconData placeholderIcon;

  const DisplayProfilePic({
    super.key,
    this.imageUrl,
    this.radius = 40,
    this.backgroundColor,
    this.placeholderIcon = Icons.person,
  });

  @override
  Widget build(BuildContext context) {
    String? _resolveUrl(String? url) {
      if (url == null || url.isEmpty) return null;
      final u = url.trim();
      if (u.startsWith('http://') || u.startsWith('https://')) {
        // Fix broken URLs missing a slash after host (e.g. https://api.luxashome.commedia/...)
        final broken = RegExp(r'^(https?:\/\/[^\/]+)media\/');
        final match = broken.firstMatch(u);
        if (match != null) {
          return u.replaceRange(match.start, match.end, '${match.group(1)!}/media/');
        }
        return u;
      }
      // Handle host-only URLs without scheme
      if (u.startsWith('api.luxashome.com') || u.startsWith('www.api.luxashome.com')) {
        return 'https://$u';
      }
      if (u.startsWith('/')) return ApiEndpoints.host + u;
      if (u.startsWith('media/')) return '${ApiEndpoints.host}/$u';
      return '${ApiEndpoints.host}/media/$u';
    }

    final resolved = _resolveUrl(imageUrl);
    final token = SharedPreferencesService().getData('user_token');
    final headers = token != null ? {'Authorization': 'Token $token'} : null;
    assert(() {
      debugPrint('[DisplayProfilePic] raw="$imageUrl" -> resolved="$resolved" tokenPresent=${token != null}');
      return true;
    }());

    final size = radius * 2;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? Colors.grey[200],
      ),
      child: resolved == null
          ? Icon(placeholderIcon, size: radius)
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: resolved,
                httpHeaders: headers,
                fit: BoxFit.cover,
                width: size,
                height: size,
                placeholder: (context, url) => Center(
                  child: SizedBox(
                    width: radius * 0.6,
                    height: radius * 0.6,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Icon(placeholderIcon, size: radius),
              ),
            ),
    );
  }
}

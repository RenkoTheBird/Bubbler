/// Compact relative timestamp matching Swift `Text(..., style: .relative)`.
String formatRelativeTime(DateTime date) {
  final now = DateTime.now();
  final local = date.toLocal();
  var diff = now.difference(local);
  if (diff.isNegative) {
    diff = Duration.zero;
  }

  if (diff.inSeconds < 60) {
    return '${diff.inSeconds}s ago';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  }
  if (diff.inDays < 30) {
    return '${diff.inDays}d ago';
  }
  final months = (diff.inDays / 30).floor();
  if (months < 12) {
    return '${months}mo ago';
  }
  return '${(diff.inDays / 365).floor()}y ago';
}

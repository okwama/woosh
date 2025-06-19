import 'package:woosh/models/outlet_model.dart';

class _ScoredOutlet {
  final Outlet outlet;
  final double score;
  _ScoredOutlet(this.outlet, this.score);
}

class OutletSearch {
  static String normalizeText(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[-\s_.,;:/\\]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<Outlet> searchOutlets(List<Outlet> outlets, String query) {
    if (query.isEmpty) return outlets;
    final patternWords = normalizeText(query).split(' ');
    print('🔍 Pattern words: $patternWords');
    final scoredOutlets = _matchAndScoreOutlets(outlets, patternWords);
    return scoredOutlets.map((so) => so.outlet).toList();
  }

  static List<_ScoredOutlet> _matchAndScoreOutlets(List<Outlet> outlets, List<String> patternWords) {
    final scoredOutlets = <_ScoredOutlet>[];
    final searchQuery = patternWords.join(' ').trim().toLowerCase();

    print('🔍 Matching outlets with query: "$searchQuery"');

    for (final outlet in outlets) {
      final name = outlet.name.trim().toLowerCase();
      final address = outlet.address?.trim().toLowerCase() ?? '';

      // Skip empty searches
      if (searchQuery.isEmpty) {
        scoredOutlets.add(_ScoredOutlet(outlet, 0.0));
        continue;
      }

      double score = 0.0;

      // Exact full string match
      if (name == searchQuery || address == searchQuery) {
        score = 1000.0;
        print('💯 Exact match found for: ${outlet.name}');
      }
      // Contains exact search query as a substring
      else if (name.contains(searchQuery) || address.contains(searchQuery)) {
        score = 800.0;
        // Boost score if it matches at word boundary
        if (name.split(' ').any((word) => word == searchQuery) ||
            address.split(' ').any((word) => word == searchQuery)) {
          score = 900.0;
          print('🎯 Word boundary match found for: ${outlet.name}');
        }
        // Boost score if it matches at start
        if (name.startsWith(searchQuery) || address.startsWith(searchQuery)) {
          score += 50.0;
          print('⭐ Start match found for: ${outlet.name}');
        }
      }
      // Partial word match
      else {
        final searchWords = searchQuery.split(' ');
        final nameWords = name.split(' ');
        final addressWords = address.split(' ');

        int matchedWords = 0;
        for (final searchWord in searchWords) {
          if (nameWords.any((word) => word.contains(searchWord)) ||
              addressWords.any((word) => word.contains(searchWord))) {
            matchedWords++;
          }
        }

        if (matchedWords > 0) {
          score = 500.0 * (matchedWords / searchWords.length);
          print('✨ Partial match found for: ${outlet.name} (Score: $score)');
        }
      }

      if (score > 0) {
        scoredOutlets.add(_ScoredOutlet(outlet, score));
      }
    }

    scoredOutlets.sort((a, b) => b.score.compareTo(a.score));
    return scoredOutlets;
  }
} 
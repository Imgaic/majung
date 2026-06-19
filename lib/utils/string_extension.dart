extension KoreanWordBreakExtension on String {
  /// 한글 단어가 줄바꿈 시 임의로 잘리는 것을 방지하기 위해,
  /// 한글 글자 사이에 Zero-Width Joiner (ZWJ, \u200D)를 삽입한 새 문자열을 반환합니다.
  String get withKoreanWordBreak {
    return split('\n').map((line) {
      return line.replaceAllMapped(
        RegExp(r'([가-힣])(?=[가-힣])'),
        (match) => '${match.group(1)}\u200D',
      );
    }).join('\n');
  }

  /// 텍스트가 일정 길이 이상일 때, 단어 경계(공백) 중에서 
  /// 전체 문장의 정중앙에 가장 가까운 곳을 찾아 줄바꿈(\n)을 명시적으로 삽입해 
  /// 두 줄의 밸런스를 자연스럽게 맞추는 기능입니다.
  String get withKoreanBalancedWrap {
    return split('\n').map((line) {
      if (line.length < 25) {
        return line;
      }

      final spaceIndices = <int>[];
      for (int i = 0; i < line.length; i++) {
        if (line[i] == ' ') {
          spaceIndices.add(i);
        }
      }

      if (spaceIndices.isEmpty) {
        return line;
      }

      final double mid = line.length / 2;
      int bestSpaceIndex = spaceIndices.first;
      double minDiff = (bestSpaceIndex - mid).abs();

      for (final index in spaceIndices) {
        final diff = (index - mid).abs();
        if (diff < minDiff) {
          minDiff = diff;
          bestSpaceIndex = index;
        }
      }

      final part1 = line.substring(0, bestSpaceIndex);
      final part2 = line.substring(bestSpaceIndex + 1);
      return '$part1\n$part2';
    }).join('\n');
  }
}

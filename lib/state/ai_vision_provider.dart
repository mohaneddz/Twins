import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which images the AI looks at when it describes a saved link. Frames are
/// YouTube's start/middle/end stills; other sites only have a thumbnail.
/// At most three images are sent, frames first.
class AiVision {
  final bool thumbnail;
  final bool start;
  final bool middle;
  final bool end;

  const AiVision({this.thumbnail = true, this.start = true, this.middle = true, this.end = true});

  AiVision copyWith({bool? thumbnail, bool? start, bool? middle, bool? end}) => AiVision(
        thumbnail: thumbnail ?? this.thumbnail,
        start: start ?? this.start,
        middle: middle ?? this.middle,
        end: end ?? this.end,
      );

  Map<String, bool> toJson() => {'thumbnail': thumbnail, 'start': start, 'middle': middle, 'end': end};
}

const _prefPrefix = 'twins_ai_vision_';

class AiVisionNotifier extends StateNotifier<AiVision> {
  AiVisionNotifier() : super(const AiVision()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AiVision(
      thumbnail: prefs.getBool('${_prefPrefix}thumbnail') ?? true,
      start: prefs.getBool('${_prefPrefix}start') ?? true,
      middle: prefs.getBool('${_prefPrefix}middle') ?? true,
      end: prefs.getBool('${_prefPrefix}end') ?? true,
    );
  }

  Future<void> set(AiVision vision) async {
    state = vision;
    final prefs = await SharedPreferences.getInstance();
    for (final entry in vision.toJson().entries) {
      await prefs.setBool('$_prefPrefix${entry.key}', entry.value);
    }
  }
}

final aiVisionProvider = StateNotifierProvider<AiVisionNotifier, AiVision>((ref) => AiVisionNotifier());

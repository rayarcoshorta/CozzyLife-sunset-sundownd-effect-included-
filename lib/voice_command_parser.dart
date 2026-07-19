enum VoiceIntent { turnOn, turnOff, setBrightness, unknown }

class VoiceCommand {
  VoiceCommand({required this.intent, this.bulbIndex, this.value});
  final VoiceIntent intent;
  final int? bulbIndex; // 0-based, null = todos
  final int? value; // 0-1000, para brillo
}

final _numberWords = {
  'uno': 1, 'dos': 2, 'tres': 3, 'cuatro': 4, 'cinco': 5,
};

VoiceCommand parseVoiceCommand(String text) {
  final t = text.toLowerCase().trim();

  int? bulbIndex;
  _numberWords.forEach((word, num) {
    if (t.contains('foco $word') || t.contains('foco ${num}')) {
      bulbIndex = num - 1;
    }
  });

  if (t.contains('enciende') || t.contains('prende')) {
    return VoiceCommand(intent: VoiceIntent.turnOn, bulbIndex: bulbIndex);
  }
  if (t.contains('apaga')) {
    return VoiceCommand(intent: VoiceIntent.turnOff, bulbIndex: bulbIndex);
  }
  final match = RegExp(r'(\d+)\s*%').firstMatch(t);
  if (match != null && (t.contains('brillo') || t.contains('pon') || t.contains('al'))) {
    final percent = int.parse(match.group(1)!);
    return VoiceCommand(
      intent: VoiceIntent.setBrightness,
      bulbIndex: bulbIndex,
      value: (percent * 10).clamp(0, 1000),
    );
  }
  return VoiceCommand(intent: VoiceIntent.unknown);
}

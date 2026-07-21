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
  
  // Soporte para "foco 1", "foco uno", "foco 2", "foco dos", etc.
  _numberWords.forEach((word, num) {
    if (t.contains('foco $word') || t.contains('foco $num') || t.contains('lampara $word') || t.contains('lámpara $num')) {
      bulbIndex = num - 1;
    }
  });

  // Otros nombres comunes
  if (t.contains('todos los focos') || t.contains('todas las luces')) {
    bulbIndex = null;
  }

  if (t.contains('enciende') || t.contains('prende') || t.contains('prender') || t.contains('encender')) {
    return VoiceCommand(intent: VoiceIntent.turnOn, bulbIndex: bulbIndex);
  }
  
  if (t.contains('apaga') || t.contains('apagar')) {
    return VoiceCommand(intent: VoiceIntent.turnOff, bulbIndex: bulbIndex);
  }

  // Mejor reconocimiento de brillo (soporta "por ciento", "%", o "al 80")
  final brightnessRegex = RegExp(r'(\d+)\s*(%|por ciento|porciento)?');
  final match = brightnessRegex.firstMatch(t);
  
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
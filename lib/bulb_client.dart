import 'dart:convert';
import 'dart:io';

/// Cliente para enviar comandos TCP a un foco CozyLife/Lightdoy.
class BulbClient {
  BulbClient({required this.ip, this.port = 5555});

  final String ip;
  final int port;

  String _timestampMs() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<String?> _sendCommand(Map<String, dynamic> payload) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));

      final jsonString = jsonEncode(payload);
      print('BulbClient -> ($ip) SEND: $jsonString');
      socket.write('$jsonString\r\n');
      await socket.flush();

      final response = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .timeout(const Duration(seconds: 3))
          .first;

      print('BulbClient <- ($ip) RECV: $response');
      return response;
    } catch (e) {
      print('BulbClient error ($ip): $e');
      return null;
    } finally {
      socket?.destroy();
    }
  }

  Future<bool> setPower(bool on) async {
    final payload = {
      'pv': 0,
      'cmd': 3,
      'sn': _timestampMs(),
      'msg': {
        'attr': [1],
        'data': {'1': on ? 255 : 0},
      },
    };
    final response = await _sendCommand(payload);
    return response != null;
  }

  Future<bool> setBrightness(int brightness) async {
    final payload = {
      'pv': 0,
      'cmd': 3,
      'sn': _timestampMs(),
      'msg': {
        'attr': [1, 4],
        'data': {'1': 255, '4': brightness},
      },
    };
    final response = await _sendCommand(payload);
    return response != null;
  }

  Future<String?> getStatus() async {
    final payload = {
      'pv': 0,
      'cmd': 2,
      'sn': _timestampMs(),
      'msg': {'attr': [1, 2, 5, 6, 7]},
    };
    return _sendCommand(payload);
  }

  /// Cambiar a modo color (HSV). Basado en el mapeo real de DPIDs:
  /// attr 2 (work_mode) = 0 para color (no 1), attr 5 = hue (0-360),
  /// attr 6 = saturación (0-1000). No se escribe attr 7 (es de solo lectura).
  Future<bool> setColor(int hue, int saturation) async {
    final payload = {
      'pv': 0,
      'cmd': 3,
      'sn': _timestampMs(),
      'msg': {
        'attr': [1, 2, 5, 6],
        'data': {'1': 255, '2': 0, '5': hue, '6': saturation},
      },
    };
    final response = await _sendCommand(payload);
    return response != null;
  }

  /// Cambiar a modo blanco/temperatura (0-1000). attr 3 = temperatura de color.
  Future<bool> setColorAndBrightness(int hue, int saturation, int brightness) async {
    final payload = {
      'pv': 0,
      'cmd': 3,
      'sn': _timestampMs(),
      'msg': {
        'attr': [1, 2, 5, 6, 4], // 1=Power, 2=Modo, 5=Hue, 6=Sat, 4=Brightness
        'data': {
          '1': 255, 
          '2': 0,    // MODO COLOR
          '5': hue, 
          '6': saturation, 
          '4': brightness
        },
      },
    };
    final response = await _sendCommand(payload);
    return response != null;
  }
  //
  Future<bool?> isPoweredOn() async {
    final raw = await getStatus();
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      final data = decoded['msg']?['data'];
      if (data == null) return null;
      final val = data['1'];
      if (val == null) return null;
      return val == 255 || val == true || val == 1;
    } catch (e) {
      print('BulbClient parse error ($ip): $e');
      return null;
    }
  }

  Future<bool> setTempAndBrightness(int temperature, int brightness) async {
    final payload = {
      'pv': 0,
      'cmd': 3,
      'sn': _timestampMs(),
      'msg': {
        'attr': [1, 2, 3, 4],
        'data': {'1': 255, '2': 0, '3': temperature, '4': brightness},
      },
    };
    final response = await _sendCommand(payload);
    return response != null;
  }
}
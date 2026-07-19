import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bulb_client.dart';
import 'main.dart'; 

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      autoStart: true, 
      isForegroundMode: true,
      notificationChannelId: 'cozylife_effects_channel',
      initialNotificationTitle: 'CozyLife Activo',
      initialNotificationContent: 'Servicio iniciado',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final Set<String> firedToday = {}; 

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) => service.setAsForegroundService());
    service.on('setAsBackground').listen((event) => service.setAsBackgroundService());
  }

  service.on('stopService').listen((event) => service.stopSelf());

  Timer.periodic(const Duration(seconds: 30), (timer) async {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final dayKey = '${now.year}-${now.month}-${now.day}';

    if (now.hour == 0 && now.minute == 0) firedToday.clear();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('bulbs_list');
    if (raw == null) return;

    try {
      final List<dynamic> decoded = jsonDecode(raw);
      final List<Bulb> bulbs = decoded.map((e) => Bulb.fromJson(e)).toList();

      for (var bulb in bulbs) {
        final ps = bulb.powerSchedule;
        
        // On/Off Programado
        if (ps.enabled) {
          final onKey = '${bulb.ip}_on_$dayKey';
          if (nowMinutes == ps.onMinutes && !firedToday.contains(onKey)) {
            firedToday.add(onKey);
            await bulb.client.setPower(true);
          }
          final offKey = '${bulb.ip}_off_$dayKey';
          if (nowMinutes == ps.offMinutes && !firedToday.contains(offKey)) {
            firedToday.add(offKey);
            await bulb.client.setPower(false);
          }
        }

        // Inicio de Efectos
        if (bulb.sunrise.enabled && bulb.sunrise.mode == 'manual') {
          final sKey = '${bulb.ip}_sr_$dayKey';
          if (nowMinutes == bulb.sunrise.manualStartMinutes && !firedToday.contains(sKey)) {
            firedToday.add(sKey);
            await bulb.client.setPower(true);
            await bulb.client.setTempAndBrightness(bulb.sunrise.startColorTemp, bulb.sunrise.startBrightness.clamp(50, 1000));
          }
        }

        if (bulb.sunset.enabled && bulb.sunset.mode == 'manual') {
          final stKey = '${bulb.ip}_st_$dayKey';
          if (nowMinutes == bulb.sunset.manualStartMinutes && !firedToday.contains(stKey)) {
            firedToday.add(stKey);
            await bulb.client.setPower(true);
            await bulb.client.setTempAndBrightness(bulb.sunset.startColorTemp, bulb.sunset.startBrightness.clamp(50, 1000));
          }
        }
      }
    } catch (e) {
      print("Error en fondo: $e");
    }

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'CozyLife Control',
        content: 'Fondo: ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')} - OK',
      );
    }
  });
}

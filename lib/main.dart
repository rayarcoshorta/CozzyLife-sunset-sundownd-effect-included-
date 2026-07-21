import 'dart:convert';
import 'bulb_client.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bulb_background_service.dart';
import 'dart:async';
import 'sunrise_sunset_calculator.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'voice_command_parser.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundService();
  runApp(const CozyLifeApp());
}

class CozyLifeApp extends StatelessWidget {
  const CozyLifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CozyLife Control',
      theme: ThemeData(
        colorSchemeSeed: Colors.amber,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class Bulb {
  Bulb({
    required this.name,
    required this.ip,
    this.isOn = false,
    this.brightness = 500,
    this.mode = 'white',
    this.colorTemp = 500,
    this.hue = 0,
    this.saturation = 1000,
    EffectConfig? sunrise,
    EffectConfig? sunset,
    PowerSchedule? powerSchedule,
  })  : client = BulbClient(ip: ip),
        sunrise = sunrise ?? EffectConfig(),
        sunset = sunset ?? EffectConfig(
          manualStartMinutes: 18 * 60,
          manualEndMinutes: 18 * 60 + 30,
          startBrightness: 1000,
          endBrightness: 50,
          startColorTemp: 1000,
          endColorTemp: 50,
          endWithRedTint: false,
        ),
        powerSchedule = powerSchedule ?? PowerSchedule();

  String name;
  final String ip;
  final BulbClient client;
  bool isOn;
  int brightness;
  String mode;
  int colorTemp;
  int hue;
  int saturation;
  EffectConfig sunrise;
  EffectConfig sunset;
  PowerSchedule powerSchedule;

  Map<String, dynamic> toJson() => {
        'name': name,
        'ip': ip,
        'isOn': isOn,
        'brightness': brightness,
        'mode': mode,
        'colorTemp': colorTemp,
        'hue': hue,
        'saturation': saturation,
        'sunrise': sunrise.toJson(),
        'sunset': sunset.toJson(),
        'powerSchedule': powerSchedule.toJson(),
      };

  factory Bulb.fromJson(Map<String, dynamic> json) => Bulb(
        name: json['name'],
        ip: json['ip'],
        isOn: json['isOn'] ?? false,
        brightness: json['brightness'] ?? 500,
        mode: json['mode'] ?? 'white',
        colorTemp: json['colorTemp'] ?? 500,
        hue: json['hue'] ?? 0,
        saturation: json['saturation'] ?? 1000,
        sunrise: EffectConfig.fromJson(json['sunrise'], isSunset: false),
        sunset: EffectConfig.fromJson(json['sunset'], isSunset: true),
        powerSchedule: PowerSchedule.fromJson(json['powerSchedule']),
      );
}

class EffectConfig {
  EffectConfig({
    this.enabled = false,
    this.mode = 'manual',
    this.manualStartMinutes = 6 * 60,
    this.manualEndMinutes = 6 * 60 + 30,
    this.startBrightness = 0,
    this.endBrightness = 1000,
    this.startColorTemp = 0,
    this.endColorTemp = 1000,
    this.endWithRedTint = false,
  });

  bool enabled;
  String mode;
  int manualStartMinutes;
  int manualEndMinutes;
  int startBrightness;
  int endBrightness;
  int startColorTemp;
  int endColorTemp;
  bool endWithRedTint;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'mode': mode,
        'manualStartMinutes': manualStartMinutes,
        'manualEndMinutes': manualEndMinutes,
        'startBrightness': startBrightness,
        'endBrightness': endBrightness,
        'startColorTemp': startColorTemp,
        'endColorTemp': endColorTemp,
        'endWithRedTint': endWithRedTint,
      };

  factory EffectConfig.fromJson(Map<String, dynamic>? json, {required bool isSunset}) {
    if (json == null) {
      return isSunset ? EffectConfig(manualStartMinutes: 18 * 60, manualEndMinutes: 18 * 60 + 30, startBrightness: 1000, endBrightness: 50, startColorTemp: 1000, endColorTemp: 50) : EffectConfig();
    }
    return EffectConfig(
      enabled: json['enabled'] ?? false,
      mode: json['mode'] ?? 'manual',
      manualStartMinutes: json['manualStartMinutes'] ?? (isSunset ? 18 * 60 : 6 * 60),
      manualEndMinutes: json['manualEndMinutes'] ?? (isSunset ? 18 * 60 + 30 : 6 * 60 + 30),
      startBrightness: json['startBrightness'] ?? (isSunset ? 1000 : 0),
      endBrightness: json['endBrightness'] ?? (isSunset ? 50 : 1000),
      startColorTemp: json['startColorTemp'] ?? (isSunset ? 1000 : 0),
      endColorTemp: json['endColorTemp'] ?? (isSunset ? 50 : 1000),
      endWithRedTint: json['endWithRedTint'] ?? false,
    );
  }
}

class PowerSchedule {
  PowerSchedule({this.enabled = false, this.onMinutes = 7 * 60, this.offMinutes = 22 * 60});
  bool enabled;
  int onMinutes;
  int offMinutes;
  Map<String, dynamic> toJson() => {'enabled': enabled, 'onMinutes': onMinutes, 'offMinutes': offMinutes};
  factory PowerSchedule.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PowerSchedule();
    return PowerSchedule(enabled: json['enabled'] ?? false, onMinutes: json['onMinutes'] ?? 7 * 60, offMinutes: json['offMinutes'] ?? 22 * 60);
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Bulb> bulbs = [];
  double? _lat;
  double? _lon;
  final Map<String, Timer> _activeEffectTimers = {};
  Timer? _schedulerTimer;
  final Set<String> _firedToday = {};
  //speach funciones
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  String _lastWords = "";

  @override
  void initState() {
    super.initState();
    _loadBulbs();
    _loadLocation();
    _startScheduler();
    _initSpeech();
  }

  @override
  void dispose() {
    for (final t in _activeEffectTimers.values) { t.cancel(); }
    _schedulerTimer?.cancel();
    super.dispose();
  }
  //Funciones de escucha
   void _initSpeech() async {
    await _speech.initialize();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('Voz Status: $val'),
        onError: (val) => print('Voz Error: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: 'es_MX', // Forzamos español de México
          onResult: (val) => setState(() {
            _lastWords = val.recognizedWords;
            if (val.finalResult) {
              _isListening = false;
              _handleVoiceCommand(_lastWords);
            }
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }


  void _handleVoiceCommand(String text) {
    final command = parseVoiceCommand(text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Comando: "$text"'), duration: const Duration(seconds: 2))
    );

    if (command.intent == VoiceIntent.unknown) return;

    List<int> targetIndices = command.bulbIndex != null 
        ? [command.bulbIndex!] 
        : List.generate(bulbs.length, (index) => index);

    for (var index in targetIndices) {
      if (index >= bulbs.length) continue;
      
      switch (command.intent) {
        case VoiceIntent.turnOn:
          _toggleBulb(index, true);
          break;
        case VoiceIntent.turnOff:
          _toggleBulb(index, false);
          break;
        case VoiceIntent.setBrightness:
          if (command.value != null) {
            _changeBrightness(index, command.value!.toDouble());
          }
          break;
        default:
          break;
      }
    }
  }
  //
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. ¿Está el GPS prendido?
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, activa el GPS')),
      );
      return;
    }

    // 2. Pedir permisos
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    // 3. Obtener ubicación
    Position position = await Geolocator.getCurrentPosition();
    
    // 4. Guardar y actualizar estado
    await _saveLocation(position.latitude, position.longitude);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ubicación actualizada: ${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}')),
    );
  }
  // --- Lógica de Control de Efectos ---
    void _runEffect(int index, {required bool isSunset}) async {
    final bulb = bulbs[index];
    final config = isSunset ? bulb.sunset : bulb.sunrise;
    if (!config.enabled) return;

    // 1. BLOQUEO: Cancelar el efecto opuesto si está activo
    final oppositeKey = '${bulb.ip}_${isSunset ? 'sunrise' : 'sunset'}';
    if (_activeEffectTimers.containsKey(oppositeKey)) {
      _activeEffectTimers[oppositeKey]?.cancel();
      _activeEffectTimers.remove(oppositeKey);
      print("Efecto opuesto cancelado para evitar cruce");
    }

    // 2. INICIO FORZADO: Asegurar que arranque con los valores de la config
    if (!bulb.isOn) {
      setState(() {
        bulb.isOn = true;
        bulb.brightness = config.startBrightness.clamp(50, 1000);
        bulb.colorTemp = config.startColorTemp;
      });
      await bulb.client.setTempAndBrightness(bulb.colorTemp, bulb.brightness);
      await Future.delayed(const Duration(milliseconds: 800));
    }

    final int startingB = bulb.brightness;
    final int startingT = bulb.colorTemp;
    final now = DateTime.now();
    DateTime start, end;

    // 3. DETERMINAR HORARIOS (Manual o Auto por GPS)
    if (config.mode == 'manual') {
      start = DateTime(now.year, now.month, now.day, config.manualStartMinutes ~/ 60, config.manualStartMinutes % 60);
      end = DateTime(now.year, now.month, now.day, config.manualEndMinutes ~/ 60, config.manualEndMinutes % 60);
    } else {
      if (_lat == null || _lon == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ubicación no configurada para modo Auto.')));
        return;
      }
      final sun = calculateSunTimes(date: now, latitude: _lat!, longitude: _lon!);
      start = isSunset ? sun.sunset : sun.civilDawn;
      end = isSunset ? sun.civilDusk : sun.sunrise;
    }

    Duration totalDuration = end.difference(start);
    if (totalDuration.isNegative || totalDuration.inMinutes == 0) return;

    final key = '${bulb.ip}_${isSunset ? 'sunset' : 'sunrise'}';
    _activeEffectTimers[key]?.cancel();

    final int stepSeconds = 10; // Cada cuánto tiempo mandamos un ajuste
    final int totalSteps = (totalDuration.inSeconds / stepSeconds).round().clamp(1, 10000);
    
    // Calcular en qué paso deberíamos estar si el efecto ya empezó
    int currentStep = now.difference(start).inSeconds ~/ stepSeconds;
    currentStep = currentStep.clamp(0, totalSteps);

    // 4. TEMPORIZADOR DE PROGRESIÓN
    _activeEffectTimers[key] = Timer.periodic(Duration(seconds: stepSeconds), (timer) async {
      currentStep++;
      double progress = currentStep / totalSteps;
      
      // Cálculo lineal de brillo y temperatura
      int currentB = (startingB + (config.endBrightness - startingB) * progress).round().clamp(50, 1000);
      int currentT = (startingT + (config.endColorTemp - startingT) * progress).round().clamp(0, 1000);

      if (mounted) {
        setState(() { 
          bulb.brightness = currentB; 
          bulb.colorTemp = currentT; 
          bulb.mode = 'white'; 
        });
      }
      
      await bulb.client.setTempAndBrightness(currentT, currentB);
      
      if (currentStep >= totalSteps) { 
        timer.cancel(); 
        _activeEffectTimers.remove(key); 
        _saveBulbs(); 
      }
    });
  }


  // --- UI y Diálogos ---
  Future<void> _showEffectDialog(int index, {required bool isSunset}) async {
    final bulb = bulbs[index];
    final config = isSunset ? bulb.sunset : bulb.sunrise;
    bool localEnabled = config.enabled;
    String localMode = config.mode;
    int sH = config.manualStartMinutes ~/ 60, sM = config.manualStartMinutes % 60;
    int eH = config.manualEndMinutes ~/ 60, eM = config.manualEndMinutes % 60;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(isSunset ? 'Atardecer' : 'Amanecer'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(title: const Text('Habilitar'), value: localEnabled, onChanged: (v) => setLocal(() => localEnabled = v)),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ChoiceChip(label: const Text('Manual'), selected: localMode == 'manual', onSelected: (v) => setLocal(() => localMode = 'manual')),
                  const SizedBox(width: 10),
                  ChoiceChip(label: const Text('Auto (Sol)'), selected: localMode == 'auto', onSelected: (v) => setLocal(() => localMode = 'auto')),
                ]),
                const SizedBox(height: 20),
                if (localMode == 'manual') ...[
                  ListTile(
                    leading: const Icon(Icons.play_arrow, color: Colors.green),
                    title: const Text('Hora Inicio'),
                    trailing: Text('${sH.toString().padLeft(2, '0')}:${sM.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    onTap: () async {
                      final p = await showTimePicker(context: context, initialTime: TimeOfDay(hour: sH, minute: sM));
                      if (p != null) setLocal(() { sH = p.hour; sM = p.minute; });
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.stop, color: Colors.red),
                    title: const Text('Hora Fin'),
                    trailing: Text('${eH.toString().padLeft(2, '0')}:${eM.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    onTap: () async {
                      final p = await showTimePicker(context: context, initialTime: TimeOfDay(hour: eH, minute: eM));
                      if (p != null) setLocal(() { eH = p.hour; eM = p.minute; });
                    },
                  ),
                ] else const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('Usa el GPS para calcular sol.', textAlign: TextAlign.center)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                setState(() { config.enabled = localEnabled; config.mode = localMode; config.manualStartMinutes = sH * 60 + sM; config.manualEndMinutes = eH * 60 + eM; });
                _saveBulbs(); 
                Navigator.pop(ctx);
                _runEffect(index, isSunset: isSunset); // Ejecutar inmediatamente si estamos en el rango
              }, 
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Persistencia y Sincronización ---
  Future<void> _loadBulbs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('bulbs_list');
    if (raw != null) {
      final List<dynamic> decoded = jsonDecode(raw);
      setState(() { bulbs = decoded.map((e) => Bulb.fromJson(e)).toList(); });
    } else {
      setState(() { bulbs = [Bulb(name: 'Foco 1', ip: '192.168.1.100')]; });
      _saveBulbs();
    }
    await _syncRealStatus();
  }

  Future<void> _syncRealStatus() async {
    for (final bulb in bulbs) {
      try {
        final real = await bulb.client.isPoweredOn();
        if (real != null && real != bulb.isOn) setState(() => bulb.isOn = real);
      } catch (_) {}
    }
  }

  void _startScheduler() { _schedulerTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkSchedules()); }

  void _checkSchedules() {
    final now = DateTime.now();
    final nowM = now.hour * 60 + now.minute;
    final dayKey = '${now.year}-${now.month}-${now.day}';
    for (var i = 0; i < bulbs.length; i++) {
      final b = bulbs[i];
      if (b.powerSchedule.enabled) {
        if (nowM == b.powerSchedule.onMinutes && !_firedToday.contains('${b.ip}_on_$dayKey')) { _firedToday.add('${b.ip}_on_$dayKey'); _toggleBulb(i, true); }
        if (nowM == b.powerSchedule.offMinutes && !_firedToday.contains('${b.ip}_off_$dayKey')) { _firedToday.add('${b.ip}_off_$dayKey'); _toggleBulb(i, false); }
      }
      if (b.sunrise.enabled && nowM == b.sunrise.manualStartMinutes && !_firedToday.contains('${b.ip}_sr_$dayKey')) { _firedToday.add('${b.ip}_sr_$dayKey'); _runEffect(i, isSunset: false); }
      if (b.sunset.enabled && nowM == b.sunset.manualStartMinutes && !_firedToday.contains('${b.ip}_st_$dayKey')) { _firedToday.add('${b.ip}_st_$dayKey'); _runEffect(i, isSunset: true); }
    }
  }

  Future<void> _saveBulbs() async { final prefs = await SharedPreferences.getInstance(); await prefs.setString('bulbs_list', jsonEncode(bulbs.map((b) => b.toJson()).toList())); }
  Future<void> _saveLocation(double lat, double lon) async { final prefs = await SharedPreferences.getInstance(); await prefs.setString('saved_location', jsonEncode({'lat': lat, 'lon': lon})); setState(() { _lat = lat; _lon = lon; }); }
  Future<void> _loadLocation() async { final prefs = await SharedPreferences.getInstance(); final raw = prefs.getString('saved_location'); if (raw != null) { final dec = jsonDecode(raw); setState(() { _lat = dec['lat']; _lon = dec['lon']; }); } }
  Future<void> _toggleBulb(int index, bool val) async { setState(() => bulbs[index].isOn = val); await bulbs[index].client.setPower(val); _saveBulbs(); }
  Future<void> _changeBrightness(int index, double v) async { int safeB = v.round().clamp(50, 1000); await bulbs[index].client.setBrightness(safeB); bulbs[index].brightness = safeB; _saveBulbs(); setState((){}); }
  Future<void> _changeColorTemp(int index, double v) async { bulbs[index].mode = 'white'; bulbs[index].colorTemp = v.round(); await bulbs[index].client.setTempAndBrightness(v.round(), bulbs[index].brightness); _saveBulbs(); setState((){}); }
  void _saveStatusManually(int i) { _saveBulbs(); if(mounted) setState((){}); }

  Future<void> _showRenameDialog(int index) async {
    final c = TextEditingController(text: bulbs[index].name);
    if (await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Renombrar'), content: TextField(controller: c), actions: [FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK'))])) == true) { setState(() => bulbs[index].name = c.text); _saveBulbs(); }
  }

  Future<void> _showLocationDialog() async {
    final laC = TextEditingController(text: _lat?.toString() ?? ''), loC = TextEditingController(text: _lon?.toString() ?? '');
    if (await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Ubicación'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: laC, decoration: const InputDecoration(labelText: 'Latitud')), TextField(controller: loC, decoration: const InputDecoration(labelText: 'Longitud'))]), actions: [FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar'))])) == true) _saveLocation(double.tryParse(laC.text) ?? 0, double.tryParse(loC.text) ?? 0);
  }

  Future<void> _showPowerScheduleDialog(int index) async {
    final config = bulbs[index].powerSchedule;
    bool en = config.enabled; int oH = config.onMinutes ~/ 60, oM = config.onMinutes % 60, fH = config.offMinutes ~/ 60, fM = config.offMinutes % 60;
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setL) => AlertDialog(title: const Text('Horario On/Off'), content: Column(mainAxisSize: MainAxisSize.min, children: [SwitchListTile(title: const Text('Activar'), value: en, onChanged: (v) => setL(() => en = v)), ListTile(title: const Text('Encender'), trailing: Text('${oH.toString().padLeft(2,'0')}:${oM.toString().padLeft(2,'0')}'), onTap: () async { final p = await showTimePicker(context: context, initialTime: TimeOfDay(hour: oH, minute: oM)); if(p!=null) setL((){oH=p.hour; oM=p.minute;}); }), ListTile(title: const Text('Apagar'), trailing: Text('${fH.toString().padLeft(2,'0')}:${fM.toString().padLeft(2,'0')}'), onTap: () async { final p = await showTimePicker(context: context, initialTime: TimeOfDay(hour: fH, minute: fM)); if(p!=null) setL((){fH=p.hour; fM=p.minute;}); })]), actions: [FilledButton(onPressed: (){ setState((){ config.enabled=en; config.onMinutes=oH*60+oM; config.offMinutes=fH*60+fM; }); _saveBulbs(); Navigator.pop(ctx); }, child: const Text('Guardar'))])));
  }

  Future<void> _showAddBulbDialog() async {
    final n = TextEditingController(), i = TextEditingController();
    if (await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Agregar foco'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n, decoration: const InputDecoration(labelText: 'Nombre')), TextField(controller: i, decoration: const InputDecoration(labelText: 'IP'))]), actions: [FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Agregar'))])) == true) { setState(() => bulbs.add(Bulb(name: n.text, ip: i.text))); _saveBulbs(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CozyLife Control'), 
        actions: [
        // Botón para detectar ubicación automáticamente por GPS
        IconButton(
          icon: const Icon(Icons.my_location), 
          onPressed: _determinePosition,
        ),
        // Botón para editar manual (el que ya tienes)
        IconButton(
          icon: const Icon(Icons.location_on), 
          onPressed: _showLocationDialog,
        ),
  ]
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: bulbs.length,
        itemBuilder: (context, index) {
          final b = bulbs[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [GestureDetector(onTap: () => _showRenameDialog(index), child: Text(b.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))), Switch(value: b.isOn, onChanged: (v) => _toggleBulb(index, v))]),
                if (b.isOn) ...[
                  const Divider(),
                  Slider(
                    value: b.brightness.toDouble().clamp(50, 1000), // Visualmente bloqueado en 50
                    min: 50, // El slider no baja de 50
                    max: 1000, 
                    onChanged: (v) => setState(() => b.brightness = v.round()), 
                    onChangeEnd: (v) => _changeBrightness(index, v)
                  ),
                  SegmentedButton<String>(segments: const [ButtonSegment(value: 'white', label: Text('Blanco')), ButtonSegment(value: 'color', label: Text('Color'))], selected: {b.mode}, onSelectionChanged: (s) => setState(() => b.mode = s.first)),
                  if (b.mode == 'white') Slider(value: b.colorTemp.toDouble(), min: 0, max: 1000, activeColor: Colors.orange, onChanged: (v) => setState(() => b.colorTemp = v.round()), onChangeEnd: (v) => _changeColorTemp(index, v))
                  else Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Column(children: [const Text('Colores'), Wrap(spacing: 8, children: [_colorPresetButton(index, 'Ruj', 0), _colorPresetButton(index, 'Ver', 120), _colorPresetButton(index, 'Azu', 240), _colorPresetButton(index, 'Ama', 60)]), Slider(value: b.saturation.toDouble(), min: 0, max: 1000, onChanged: (v) => setState(() => b.saturation = v.round()), onChangeEnd: (v) { b.client.setColorAndBrightness(b.hue, b.saturation, b.brightness); _saveBulbs(); })])),
                  const Divider(),
                  Row(children: [Expanded(child: OutlinedButton(onPressed: () => _showEffectDialog(index, isSunset: false), child: const Text('Amanecer'))), const SizedBox(width: 8), Expanded(child: OutlinedButton(onPressed: () => _showEffectDialog(index, isSunset: true), child: const Text('Atardecer')))]),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: const Icon(Icons.schedule), label: const Text('Horario On/Off'), onPressed: () => _showPowerScheduleDialog(index))),
                ]
              ]),
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _listen,
            backgroundColor: _isListening ? Colors.red : Colors.amber,
            heroTag: 'voiceBtn',
            child: Icon(_isListening ? Icons.mic : Icons.mic_none),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            onPressed: _showAddBulbDialog,
            mini: true,
            heroTag: 'addBtn',
            child: const Icon(Icons.add),
    
          ),
        ],
      ),      
    );
  }

  Widget _colorPresetButton(int index, String label, int hue) {
    final b = bulbs[index];
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: HSVColor.fromAHSV(1, hue.toDouble(), 1.0, 1.0).toColor(), minimumSize: const Size(45, 45), shape: const CircleBorder()),
      onPressed: () async { setState(() { b.hue = hue; b.saturation = 1000; }); await b.client.setColorAndBrightness(b.hue, b.saturation, b.brightness); _saveBulbs(); },
      child: const SizedBox.shrink(),
    );
  }
}

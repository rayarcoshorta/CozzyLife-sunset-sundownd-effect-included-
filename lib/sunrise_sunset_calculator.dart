import 'dart:math';

/// Resultado del cálculo solar para una fecha y ubicación dadas.
class SunTimes {
  SunTimes({
    required this.civilDawn,
    required this.sunrise,
    required this.sunset,
    required this.civilDusk,
  });

  final DateTime civilDawn; // Inicio de la luz civil (antes del amanecer)
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime civilDusk; // Fin de la luz civil (después del atardecer)

  Duration get sunriseDuration => sunrise.difference(civilDawn);
  Duration get sunsetDuration => civilDusk.difference(sunset);
}

/// Calcula horas de amanecer/atardecer y crepúsculo civil (elevación solar -6°)
/// para una fecha (local) y coordenadas dadas. Basado en el algoritmo NOAA.
SunTimes calculateSunTimes({
  required DateTime date,
  required double latitude,
  required double longitude,
}) {
  final dawnUtc = _solarEventUtc(date, latitude, longitude, -6, isSunrise: true);
  final sunriseUtc = _solarEventUtc(date, latitude, longitude, -0.833, isSunrise: true);
  final sunsetUtc = _solarEventUtc(date, latitude, longitude, -0.833, isSunrise: false);
  final duskUtc = _solarEventUtc(date, latitude, longitude, -6, isSunrise: false);

  return SunTimes(
    civilDawn: dawnUtc.toLocal(),
    sunrise: sunriseUtc.toLocal(),
    sunset: sunsetUtc.toLocal(),
    civilDusk: duskUtc.toLocal(),
  );
}

double _deg2rad(double deg) => deg * pi / 180;
double _rad2deg(double rad) => rad * 180 / pi;

DateTime _solarEventUtc(
  DateTime date,
  double lat,
  double lon,
  double elevationDeg, {
  required bool isSunrise,
}) {
  final dayOfYear = int.parse(
    '${date.difference(DateTime(date.year, 1, 1)).inDays + 1}',
  );

  // Ángulo fraccional del año (radianes)
  final gamma = 2 * pi / 365 * (dayOfYear - 1);

  // Ecuación del tiempo (minutos)
  final eqTime = 229.18 *
      (0.000075 +
          0.001868 * cos(gamma) -
          0.032077 * sin(gamma) -
          0.014615 * cos(2 * gamma) -
          0.040849 * sin(2 * gamma));

  // Declinación solar (radianes)
  final decl = 0.006918 -
      0.399912 * cos(gamma) +
      0.070257 * sin(gamma) -
      0.006758 * cos(2 * gamma) +
      0.000907 * sin(2 * gamma) -
      0.002697 * cos(3 * gamma) +
      0.00148 * sin(3 * gamma);

  final latRad = _deg2rad(lat);
  final zenith = _deg2rad(90 - elevationDeg);

  final cosHourAngle =
      (cos(zenith) - sin(latRad) * sin(decl)) / (cos(latRad) * cos(decl));

  // Si el sol no sale/se pone ese día (latitudes extremas), usamos mediodía como referencia.
  final clamped = cosHourAngle.clamp(-1.0, 1.0);
  final hourAngle = acos(clamped);

  final hourAngleDeg = isSunrise ? -_rad2deg(hourAngle) : _rad2deg(hourAngle);

  // Minutos desde medianoche UTC
  final timeOffsetMin = 720 - 4 * (lon + hourAngleDeg) - eqTime;

  final utcMidnight = DateTime.utc(date.year, date.month, date.day);
  return utcMidnight.add(Duration(milliseconds: (timeOffsetMin * 60000).round()));
}
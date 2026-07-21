# CozyLife Control 
CozyLife Control es una aplicación desarrollada en **Flutter** diseñada para el control avanzado de iluminación inteligente mediante el protocolo **JSON sobre TCP**. A diferencia de las apps comerciales estándar, esta solución permite una automatización profunda y transiciones de iluminación personalizadas.

---

## Características Principales

- **Control TCP Directo:** Comunicación bidireccional de baja latencia con dispositivos en el puerto `5555`.
- **Efectos de Amanecer y Atardecer:** Algoritmo dinámico que ajusta el brillo y la temperatura de color de forma imperceptible basándose en intervalos de tiempo programables (ej. transiciones suaves de 2 horas).
- **Modo Solar (GPS):** Integración con cálculos astronómicos para sincronizar las luces con la salida y puesta del sol real según la ubicación del usuario.
- **Servicio en Primer Plano (Foreground Service):** Optimizado para **Android 16** (POCO F7 Ultra), permitiendo que los horarios se ejecuten de manera confiable incluso cuando la aplicación está cerrada o la pantalla bloqueada.
- **Persistencia Local:** Gestión de dispositivos y configuraciones mediante `SharedPreferences`.

## Stack Tecnológico

- **Framework:** Flutter (Dart)
- **Comunicación:** Sockets TCP (Protocolo Raw JSON)
- **Arquitectura:** Gestión de estado nativa y servicios desacoplados para lógica de red (`BulbClient`).
- **Seguridad de Hardware:** Implementación de bloqueos de voltaje mínimo (brillo min 50) para prevenir el apagado físico de los componentes electrónicos del foco.

## Estado del Proyecto

Actualmente, la aplicación es totalmente funcional para el control manual y automatico, por horarios y por efectos solares. 
Tiene ubicación GPS automático y efectos vinculados a los horarios, así como reconocimiento de voz.

## Instalación y Uso

1. Asegúrate de que tus focos sean compatibles con el protocolo CozyLife en el puerto 5555.
2. Clona el repositorio:
   ```bash
   git clone https://github.com/rayarcoshorta/CozzyLife-sunset-sundownd-effect-included-.git

enum IrrigationMode { manual, scheduled, automatic }

enum IrrigationValve { nebulization, dripMicroSprinkler }

enum IrrigationSource { manual, scheduled, automatic }

enum DeviceStatus { online, offline, irrigating }

class SensorReading {
  const SensorReading({
    required this.soilMoisture,
    required this.temperature,
    required this.airHumidity,
    required this.pressure,
    required this.illuminance,
    required this.lowWater,
    required this.recordedAt,
  });
  final double soilMoisture;
  final double temperature;
  final double airHumidity;
  final double pressure;
  final double illuminance;
  final bool lowWater;
  final DateTime recordedAt;
}

class PlantProfile {
  const PlantProfile({
    required this.name,
    this.scientificName,
    this.soilMoistureLimit,
  });
  final String name;
  final String? scientificName;
  final double? soilMoistureLimit;
}

class IrrigationDevice {
  const IrrigationDevice({
    required this.id,
    required this.name,
    this.status = DeviceStatus.offline,
  });
  final String id;
  final String name;
  final DeviceStatus status;
}

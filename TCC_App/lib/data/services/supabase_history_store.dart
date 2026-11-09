import 'package:supabase_flutter/supabase_flutter.dart';

class SensorReadingRecord {
  const SensorReadingRecord({
    required this.soilMoisture,
    required this.temperature,
    required this.airHumidity,
    required this.illuminance,
    required this.recordedAt,
  });

  final double? soilMoisture;
  final double? temperature;
  final double? airHumidity;
  final double? illuminance;
  final DateTime recordedAt;
}

class IrrigationEventRecord {
  const IrrigationEventRecord({
    required this.valve,
    required this.mode,
    required this.startedAt,
    required this.durationSeconds,
    required this.status,
    this.cancellationReason,
  });

  final String valve;
  final String mode;
  final DateTime startedAt;
  final int? durationSeconds;
  final String status;
  final String? cancellationReason;
}

class SupabaseHistoryStore {
  SupabaseHistoryStore(this.client);

  final SupabaseClient client;

  Future<List<SensorReadingRecord>> listReadings({
    required String plantId,
    required DateTime from,
  }) async {
    final rows = await client
        .from('sensor_readings')
        .select(
          'soil_moisture, temperature, air_humidity, illuminance, recorded_at',
        )
        .eq('plant_id', plantId)
        .gte('recorded_at', from.toUtc().toIso8601String())
        .order('recorded_at');
    return [
      for (final row in rows)
        SensorReadingRecord(
          soilMoisture: _toDouble(row['soil_moisture']),
          temperature: _toDouble(row['temperature']),
          airHumidity: _toDouble(row['air_humidity']),
          illuminance: _toDouble(row['illuminance']),
          recordedAt: DateTime.parse(row['recorded_at'] as String),
        ),
    ];
  }

  Future<List<IrrigationEventRecord>> listEvents({
    required String plantId,
    required DateTime from,
  }) async {
    final rows = await client
        .from('irrigation_events')
        .select(
          'valve, mode, started_at, duration_seconds, status, cancellation_reason',
        )
        .eq('plant_id', plantId)
        .gte('started_at', from.toUtc().toIso8601String())
        .order('started_at', ascending: false);
    return [
      for (final row in rows)
        IrrigationEventRecord(
          valve: row['valve'] as String,
          mode: row['mode'] as String,
          startedAt: DateTime.parse(row['started_at'] as String),
          durationSeconds: row['duration_seconds'] as int?,
          status: row['status'] as String,
          cancellationReason: row['cancellation_reason'] as String?,
        ),
    ];
  }

  static double? _toDouble(Object? value) =>
      value == null ? null : (value as num).toDouble();
}

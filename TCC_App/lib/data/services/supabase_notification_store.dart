import 'package:supabase_flutter/supabase_flutter.dart';

class PlantNotificationPreferences {
  const PlantNotificationPreferences({
    this.irrigationCompleted = true,
    this.excessiveLight = true,
    this.excessiveLightLimit = 80,
    this.thermalStress = true,
    this.thermalMax = 30,
    this.drySoil = true,
    this.drySoilLimit = 35,
    this.dryAir = false,
    this.dryAirLimit = 35,
    this.manualCompleted = true,
    this.safetyWatchdog = true,
  });

  final bool irrigationCompleted;
  final bool excessiveLight;
  final double excessiveLightLimit;
  final bool thermalStress;
  final double thermalMax;
  final bool drySoil;
  final double drySoilLimit;
  final bool dryAir;
  final double dryAirLimit;
  final bool manualCompleted;
  final bool safetyWatchdog;

  factory PlantNotificationPreferences.fromMap(Map<String, dynamic> row) =>
      PlantNotificationPreferences(
        irrigationCompleted: row['irrigation_completed'] as bool? ?? true,
        excessiveLight: row['excessive_light'] as bool? ?? true,
        excessiveLightLimit: _number(row['excessive_light_limit'], 80),
        thermalStress: row['thermal_stress'] as bool? ?? true,
        thermalMax: _number(row['thermal_max'], 30),
        drySoil: row['dry_soil'] as bool? ?? true,
        drySoilLimit: _number(row['dry_soil_limit'], 35),
        dryAir: row['dry_air'] as bool? ?? false,
        dryAirLimit: _number(row['dry_air_limit'], 35),
        manualCompleted: row['manual_completed'] as bool? ?? true,
        safetyWatchdog: row['safety_watchdog'] as bool? ?? true,
      );

  Map<String, dynamic> toMap(String plantId) => {
    'plant_id': plantId,
    'irrigation_completed': irrigationCompleted,
    'excessive_light': excessiveLight,
    'excessive_light_limit': excessiveLightLimit,
    'thermal_stress': thermalStress,
    'thermal_max': thermalMax,
    'dry_soil': drySoil,
    'dry_soil_limit': drySoilLimit,
    'dry_air': dryAir,
    'dry_air_limit': dryAirLimit,
    'manual_completed': manualCompleted,
    'safety_watchdog': safetyWatchdog,
  };

  static double _number(Object? value, double fallback) =>
      value is num ? value.toDouble() : fallback;
}

class SupabaseNotificationStore {
  SupabaseNotificationStore(this.client);
  final SupabaseClient client;

  Future<PlantNotificationPreferences> load(String plantId) async {
    final row = await client
        .from('plant_notification_preferences')
        .select()
        .eq('plant_id', plantId)
        .maybeSingle();
    if (row == null) return const PlantNotificationPreferences();
    return PlantNotificationPreferences.fromMap(row);
  }

  Future<void> save(
    String plantId,
    PlantNotificationPreferences preferences,
  ) async {
    final care = await client
        .from('plant_care_configs')
        .select('irrigation_mode')
        .eq('plant_id', plantId)
        .maybeSingle();
    final isManual = care?['irrigation_mode'] == 'manual';
    final values = preferences.toMap(plantId);
    if (!isManual) {
      values['dry_soil'] = false;
      values['dry_air'] = false;
    }
    await client
        .from('plant_notification_preferences')
        .upsert(values, onConflict: 'plant_id');
  }
}

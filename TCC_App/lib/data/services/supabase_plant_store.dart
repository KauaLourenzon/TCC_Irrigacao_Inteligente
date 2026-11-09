import 'package:supabase_flutter/supabase_flutter.dart';

class ScheduleTimeInput {
  const ScheduleTimeInput({
    required this.timeOfDay,
    this.durationSeconds,
    this.valve = 'valve_2',
  });

  final String timeOfDay;
  final int? durationSeconds;
  final String valve;
}

class SupabasePlantRecord {
  const SupabasePlantRecord({
    required this.id,
    required this.name,
    required this.mode,
    required this.valve2Mode,
    required this.frequencyDays,
    required this.scheduleTimes,
  });

  final String id;
  final String name;
  final String mode;
  final String valve2Mode;
  final String frequencyDays;
  final List<ScheduleTimeInput> scheduleTimes;
}

class SupabasePlantStore {
  SupabasePlantStore(this.client);

  final SupabaseClient client;

  Future<List<SupabasePlantRecord>> listPlants() async {
    final plants = await client
        .from('plants')
        .select('id, popular_name')
        .order('created_at');
    final care = await client
        .from('plant_care_configs')
        .select('plant_id, irrigation_mode, valve_2_mode');
    final schedules = await client
        .from('irrigation_schedules')
        .select('id, plant_id, frequency_days');
    final scheduleIds = [for (final row in schedules) row['id'] as String];
    final scheduleTimes = scheduleIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await client
              .from('irrigation_schedule_times')
              .select(
                'schedule_id, time_of_day, duration_seconds, valve, sort_order',
              )
              .inFilter('schedule_id', scheduleIds)
              .order('sort_order');
    final timesBySchedule = <String, List<ScheduleTimeInput>>{};
    for (final row in scheduleTimes) {
      (timesBySchedule[row['schedule_id'] as String] ??= []).add(
        ScheduleTimeInput(
          timeOfDay: row['time_of_day'] as String,
          durationSeconds: row['duration_seconds'] as int?,
          valve: row['valve'] as String? ?? 'valve_2',
        ),
      );
    }

    final careByPlant = <String, Map<String, dynamic>>{
      for (final row in care) row['plant_id'] as String: row,
    };
    final scheduleByPlant = <String, Map<String, dynamic>>{
      for (final row in schedules) row['plant_id'] as String: row,
    };

    return [
      for (final row in plants)
        SupabasePlantRecord(
          id: row['id'] as String,
          name: row['popular_name'] as String,
          mode: _displayMode(
            careByPlant[row['id'] as String]?['irrigation_mode'],
          ),
          valve2Mode: _displayValve(
            careByPlant[row['id'] as String]?['valve_2_mode'],
          ),
          frequencyDays:
              '${scheduleByPlant[row['id'] as String]?['frequency_days'] ?? 1}',
          scheduleTimes:
              timesBySchedule[scheduleByPlant[row['id'] as String]?['id']
                  as String?] ??
              const [],
        ),
    ];
  }

  Future<String> createPlant({
    required String name,
    String? scientificName,
    required String mode,
    required String valve2Mode,
    required int frequencyDays,
    String finishMode = 'duration',
    int durationSeconds = 30,
    double soilTrigger = 35,
    double? soilHumidityTarget,
    List<ScheduleTimeInput> scheduleTimes = const [],
  }) async {
    final row = await client
        .from('plants')
        .insert({
          'user_id': client.auth.currentUser!.id,
          'popular_name': name,
          'scientific_name': scientificName,
        })
        .select('id')
        .single();
    final plantId = row['id'] as String;
    await saveConfiguration(
      plantId: plantId,
      mode: mode,
      valve2Mode: valve2Mode,
      frequencyDays: frequencyDays,
      finishMode: finishMode,
      durationSeconds: durationSeconds,
      soilTrigger: soilTrigger,
      soilHumidityTarget: soilHumidityTarget,
      scheduleTimes: scheduleTimes,
    );
    return plantId;
  }

  Future<void> saveConfiguration({
    required String plantId,
    required String mode,
    required String valve2Mode,
    required int frequencyDays,
    String finishMode = 'duration',
    int durationSeconds = 30,
    double soilTrigger = 35,
    double? soilHumidityTarget,
    List<ScheduleTimeInput> scheduleTimes = const [],
  }) async {
    await client.from('plant_care_configs').upsert({
      'plant_id': plantId,
      'irrigation_mode': _databaseMode(mode),
      'valve_2_mode': _databaseValve(valve2Mode),
      'soil_trigger': soilTrigger,
    }, onConflict: 'plant_id');
    final schedule = {
      'plant_id': plantId,
      'frequency_days': frequencyDays,
      'times_per_day': 1,
      'finish_mode': finishMode == 'Umidade' ? 'soil_humidity' : 'duration',
      'duration_seconds': finishMode == 'Umidade' ? null : durationSeconds,
      'soil_humidity_target': finishMode == 'Umidade'
          ? (soilHumidityTarget ?? 50)
          : null,
      'active': true,
    };
    final existingSchedule = await client
        .from('irrigation_schedules')
        .select('id')
        .eq('plant_id', plantId)
        .maybeSingle();
    late final String scheduleId;
    if (existingSchedule == null) {
      final inserted = await client
          .from('irrigation_schedules')
          .insert(schedule)
          .select('id')
          .single();
      scheduleId = inserted['id'] as String;
    } else {
      await client
          .from('irrigation_schedules')
          .update(schedule)
          .eq('id', existingSchedule['id']);
      scheduleId = existingSchedule['id'] as String;
    }
    await client
        .from('irrigation_schedule_times')
        .delete()
        .eq('schedule_id', scheduleId);
    if (scheduleTimes.isNotEmpty) {
      await client.from('irrigation_schedule_times').insert([
        for (var index = 0; index < scheduleTimes.length; index++)
          {
            'schedule_id': scheduleId,
            'time_of_day': scheduleTimes[index].timeOfDay,
            'duration_seconds': scheduleTimes[index].durationSeconds,
            'valve': scheduleTimes[index].valve,
            'sort_order': index,
          },
      ]);
    }
  }

  Future<void> renamePlant(String plantId, String name) async {
    await client
        .from('plants')
        .update({'popular_name': name})
        .eq('id', plantId);
  }

  Future<void> deletePlant(String plantId) async {
    await client.from('plants').delete().eq('id', plantId);
  }

  static String _databaseMode(String mode) => switch (mode) {
    'Manual' => 'manual',
    'Programado' => 'scheduled',
    _ => 'intelligent',
  };

  static String _displayMode(Object? mode) => switch (mode) {
    'manual' => 'Manual',
    'scheduled' => 'Programado',
    _ => 'Inteligente',
  };

  static String _databaseValve(String mode) =>
      mode == 'Microaspersão' ? 'micro_sprinkler' : 'drip';

  static String _displayValve(Object? mode) =>
      mode == 'micro_sprinkler' ? 'Microaspersão' : 'Gotejamento';
}

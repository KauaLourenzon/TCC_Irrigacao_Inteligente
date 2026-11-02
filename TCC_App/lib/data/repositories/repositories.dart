import '../../domain/models/models.dart';

abstract interface class AuthRepository {
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password);
  Future<void> resetPassword(String email);
  Future<void> signOut();
}

abstract interface class DeviceRepository {
  Stream<SensorReading> watchTelemetry(String deviceId);
  Future<List<IrrigationDevice>> listDevices();
  Future<void> sendManualCommand(
    String deviceId,
    IrrigationValve valve,
    Duration duration,
  );
  Future<void> synchronizeConfiguration(String deviceId);
}

abstract interface class PlantRepository {
  Future<List<PlantProfile>> listPlants();
  Future<PlantProfile> identifyFromImage(String imagePath);
}

abstract interface class HistoryRepository {
  Future<List<SensorReading>> listReadings(String deviceId);
}

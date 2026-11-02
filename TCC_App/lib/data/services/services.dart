/// Integrações externas previstas no escopo, mantidas isoladas da UI.
abstract interface class Esp32LocalProvisioningService {
  Future<List<String>> scanNetworks();
  Future<void> configureNetwork({
    required String ssid,
    required String password,
    required String deviceToken,
  });
}

abstract interface class AiPlantService {
  Future<Map<String, dynamic>> diagnosePlant(String imagePath);
}

abstract interface class NotificationService {
  Future<void> initialize();
  Future<void> registerDeviceToken();
}

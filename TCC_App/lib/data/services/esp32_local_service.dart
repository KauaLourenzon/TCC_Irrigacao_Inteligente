import 'package:dio/dio.dart';
import 'package:multicast_dns/multicast_dns.dart';

/// Cliente HTTP do ESP32 na rede local.
///
/// Durante o provisionamento o telefone deve estar conectado ao Access Point
/// do ESP32, normalmente em http://192.168.4.1. Depois que o ESP32 entra na
/// rede residencial, o endereco dele precisa ser descoberto/configurado para
/// continuar recebendo comandos pela rede local.
class Esp32LocalService {
  Esp32LocalService({Dio? client}) : _client = client ?? Dio();

  final Dio _client;

  /// Descobre o ESP32 que anuncia o servico HTTP via mDNS.
  /// Retorna uma URL como http://192.168.1.42:80 ou null quando nao encontra.
  Future<String?> discoverByMdns({Duration timeout = const Duration(seconds: 4)}) async {
    final client = MDnsClient();
    try {
      await client.start();
      final deadline = DateTime.now().add(timeout);
      await for (final ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('_http._tcp.local'),
      )) {
        if (!ptr.domainName.toLowerCase().contains('irrigacao-esp32')) continue;
        await for (final service in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          await for (final address in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(service.target),
          )) {
            return 'http://${address.address.address}:${service.port}';
          }
        }
        if (DateTime.now().isAfter(deadline)) break;
      }
    } finally {
      client.stop();
    }
    return null;
  }

  Future<bool> isReachable({String baseUrl = 'http://192.168.4.1'}) async {
    try {
      await _client.get<Map<String, dynamic>>(
        '$baseUrl/api/telemetry',
        options: Options(connectTimeout: const Duration(seconds: 3), receiveTimeout: const Duration(seconds: 3)),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Esp32WifiNetwork>> scanNetworks({
    String baseUrl = 'http://192.168.4.1',
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '$baseUrl/networks',
      options: Options(connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)),
    );
    final data = response.data?['redes'];
    if (data is! List) return const [];
    return [
      for (final item in data.whereType<Map>())
        Esp32WifiNetwork(
          ssid: item['ssid']?.toString() ?? '',
          signal: (item['sinal'] as num?)?.toInt() ?? 0,
          secured: item['segura'] == true,
        ),
    ];
  }

  Future<void> configureNetwork({
    String baseUrl = 'http://192.168.4.1',
    required String ssid,
    required String password,
    String deviceToken = '',
    String plantId = '',
  }) async {
    await _client.post<void>(
      '$baseUrl/config',
      data: {
        'ssid': ssid,
        'senha': password,
        'device_token': deviceToken,
        'plant_id': plantId,
      },
      options: Options(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
  }

  Future<Map<String, dynamic>> telemetry({required String baseUrl}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '$baseUrl/api/telemetry',
      options: Options(connectTimeout: const Duration(seconds: 3), receiveTimeout: const Duration(seconds: 3)),
    );
    return response.data ?? const {};
  }

  Future<void> sendCommand({
    required String baseUrl,
    required String action,
    int valve = 1,
    int durationSeconds = 30,
  }) async {
    await _client.post<void>(
      '$baseUrl/api/command',
      data: {
        'acao': action,
        'valvula': valve,
        'duracao_segundos': durationSeconds,
      },
    );
  }

  Future<void> sendConfiguration({
    required String baseUrl,
    required Map<String, dynamic> configuration,
  }) async {
    await _client.post<void>('$baseUrl/api/config', data: configuration);
  }

  Future<void> reset({required String baseUrl}) async {
    await _client.post<void>('$baseUrl/api/reset');
  }
}

class Esp32WifiNetwork {
  const Esp32WifiNetwork({
    required this.ssid,
    required this.signal,
    required this.secured,
  });

  final String ssid;
  final int signal;
  final bool secured;
}

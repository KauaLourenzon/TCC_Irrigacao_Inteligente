import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/supabase_plant_store.dart';
import '../../data/services/supabase_history_store.dart';
import '../../data/services/supabase_notification_store.dart';
import '../../data/services/esp32_local_service.dart';

const _green = Color(0xFF00513E);
const _greenDark = Color(0xFF003F32);
const _mint = Color(0xFFE7F6EC);
const _background = Color(0xFFF7FAF5);
const _showWaterAlert = false;

void showNotificationDrawer(BuildContext context) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Notificações',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) => Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: _NotificationDrawer(onClose: () => Navigator.pop(context)),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
  );
}

class _AppNotification {
  _AppNotification({
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    this.critical = false,
  });

  final String title;
  final String message;
  final String time;
  final IconData icon;
  final bool critical;
}

class _NotificationDrawer extends StatefulWidget {
  const _NotificationDrawer({required this.onClose});
  final VoidCallback onClose;

  @override
  State<_NotificationDrawer> createState() => _NotificationDrawerState();
}

class _NotificationDrawerState extends State<_NotificationDrawer> {
  final notifications = <_AppNotification>[
    _AppNotification(
      title: 'Irrigação concluída',
      message: 'A Válvula 2 foi encerrada com sucesso.',
      time: 'Hoje, 07:00',
      icon: Icons.check_circle_outline,
    ),
    _AppNotification(
      title: 'Solo seco',
      message: 'A umidade do solo está abaixo do limite configurado.',
      time: 'Ontem, 18:00',
      icon: Icons.water_drop_outlined,
    ),
    _AppNotification(
      title: 'Atenção ao reservatório',
      message: 'O nível de água está baixo.',
      time: 'Ontem, 12:20',
      icon: Icons.warning_amber_rounded,
      critical: true,
    ),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      width: MediaQuery.sizeOf(context).width * .86,
      height: double.infinity,
      color: _background,
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Notificações',
                  style: TextStyle(
                    color: _greenDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (notifications.isNotEmpty)
                TextButton(
                  onPressed: () => setState(notifications.clear),
                  child: const Text('Apagar todas'),
                ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          if (notifications.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Nenhuma notificação',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: notifications.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: notification.critical
                          ? Colors.red.withValues(alpha: .12)
                          : _mint,
                      child: Icon(
                        notification.icon,
                        color: notification.critical ? Colors.red : _green,
                      ),
                    ),
                    title: Text(
                      notification.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${notification.message}\n${notification.time}',
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: 'Apagar notificação',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          setState(() => notifications.removeAt(index)),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}

class MockAppShell extends StatefulWidget {
  const MockAppShell({this.useSupabase = false, super.key});

  final bool useSupabase;

  @override
  State<MockAppShell> createState() => _MockAppShellState();
}

class _MockAppShellState extends State<MockAppShell> {
  static const _plantsStorageKey = 'mock_plants_v2';
  static const _irrigationModeStorageKey = 'mock_irrigation_mode';
  bool isLoading = true;
  bool isAddingPlant = false;
  bool isEditingPlant = false;
  int selectedIndex = 0;
  String plantName = '';
  String irrigationMode = 'Inteligente';
  String valve2Mode = 'Gotejamento';
  String pendingFrequency = '1';
  String pendingFinishMode = 'Duração';
  int pendingDurationSeconds = 30;
  double pendingSoilTrigger = 35;
  double pendingSoilHumidityTarget = 50;
  List<ScheduleTimeInput> pendingScheduleTimes = const [];
  final plantNames = <String>[];
  final plantModes = <String, String>{};
  final plantValve2Modes = <String, String>{};
  final plantFrequencies = <String, String>{};
  final plantScheduleTimes = <String, List<ScheduleTimeInput>>{};
  final plantIds = <String, String>{};
  SupabasePlantStore? plantStore;
  SupabaseHistoryStore? historyStore;
  SupabaseNotificationStore? notificationStore;

  @override
  void initState() {
    super.initState();
    if (widget.useSupabase) {
      plantStore = SupabasePlantStore(Supabase.instance.client);
      historyStore = SupabaseHistoryStore(Supabase.instance.client);
      notificationStore = SupabaseNotificationStore(Supabase.instance.client);
    }
    _loadPlants();
  }

  Future<void> _loadPlants() async {
    if (plantStore != null) {
      // Ao usar o backend real, os dados antigos do protótipo local não
      // participam mais do fluxo e são removidos do dispositivo.
      final preferences = await SharedPreferences.getInstance();
      await Future.wait([
        preferences.remove(_plantsStorageKey),
        preferences.remove(_irrigationModeStorageKey),
        preferences.remove('mock_plant_modes'),
        preferences.remove('mock_plant_valves'),
        preferences.remove('mock_plant_frequencies'),
      ]);
      try {
        final loadedRecords = await plantStore!.listPlants();
        // O seletor usa o nome como valor; nomes repetidos quebram o
        // DropdownButton. Mantemos apenas o primeiro registro exibido.
        final uniqueRecords = <String, SupabasePlantRecord>{};
        for (final record in loadedRecords) {
          uniqueRecords.putIfAbsent(record.name, () => record);
        }
        final records = uniqueRecords.values.toList();
        if (!mounted) return;
        setState(() {
          plantNames
            ..clear()
            ..addAll(records.map((record) => record.name));
          plantIds
            ..clear()
            ..addEntries(
              records.map((record) => MapEntry(record.name, record.id)),
            );
          plantModes
            ..clear()
            ..addEntries(
              records.map((record) => MapEntry(record.name, record.mode)),
            );
          plantValve2Modes
            ..clear()
            ..addEntries(
              records.map((record) => MapEntry(record.name, record.valve2Mode)),
            );
          plantFrequencies
            ..clear()
            ..addEntries(
              records.map(
                (record) => MapEntry(record.name, record.frequencyDays),
              ),
            );
          plantScheduleTimes
            ..clear()
            ..addEntries(
              records.map(
                (record) => MapEntry(record.name, record.scheduleTimes),
              ),
            );
          plantName = plantNames.isEmpty ? '' : plantNames.first;
          irrigationMode = plantModes[plantName] ?? 'Inteligente';
          valve2Mode = plantValve2Modes[plantName] ?? 'Gotejamento';
          isLoading = false;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar plantas: $error')),
        );
      }
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    // Remove a persistência antiga usada pelos mocks anteriores.
    await preferences.remove('mock_plants');
    final savedPlants = preferences.getStringList(_plantsStorageKey) ?? [];
    final savedIrrigationMode = preferences.getString(
      _irrigationModeStorageKey,
    );
    final savedPlantModes = _decodeConfigurationMap(
      preferences.getString('mock_plant_modes'),
    );
    final savedPlantValves = _decodeConfigurationMap(
      preferences.getString('mock_plant_valves'),
    );
    final savedPlantFrequencies = _decodeConfigurationMap(
      preferences.getString('mock_plant_frequencies'),
    );
    if (!mounted) return;
    setState(() {
      plantNames
        ..clear()
        ..addAll(savedPlants.toSet());
      plantName = plantNames.isEmpty ? '' : plantNames.first;
      plantModes.addAll(savedPlantModes);
      plantValve2Modes.addAll(savedPlantValves);
      plantFrequencies.addAll(savedPlantFrequencies);
      final selectedMode = plantModes[plantName];
      final selectedValve = plantValve2Modes[plantName];
      if (selectedMode != null) irrigationMode = selectedMode;
      if (selectedValve != null) valve2Mode = selectedValve;
      if (savedIrrigationMode == 'Manual' ||
          savedIrrigationMode == 'Programado' ||
          savedIrrigationMode == 'Inteligente') {
        irrigationMode = savedIrrigationMode!;
      }
      isLoading = false;
    });
  }

  Future<void> _savePlants() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_plantsStorageKey, List.of(plantNames));
  }

  Future<void> _saveIrrigationMode(String mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_irrigationModeStorageKey, mode);
  }

  Map<String, String> _decodeConfigurationMap(String? value) {
    if (value == null) return {};
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }
    } catch (_) {
      // Dados antigos ou inválidos serão substituídos pelos padrões.
    }
    return {};
  }

  Future<void> _savePlantConfigurations() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('mock_plant_modes', jsonEncode(plantModes));
    await preferences.setString(
      'mock_plant_valves',
      jsonEncode(plantValve2Modes),
    );
    await preferences.setString(
      'mock_plant_frequencies',
      jsonEncode(plantFrequencies),
    );
  }

  Future<void> addPlant(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return;
    if (plantStore != null) {
      if (plantNames.contains(normalizedName)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Essa planta já está cadastrada.')),
          );
        }
        return;
      }
      final id = await plantStore!.createPlant(
        name: normalizedName,
        mode: irrigationMode,
        valve2Mode: valve2Mode,
        frequencyDays: int.tryParse(pendingFrequency) ?? 1,
        finishMode: pendingFinishMode,
        durationSeconds: pendingDurationSeconds,
        soilTrigger: pendingSoilTrigger,
        soilHumidityTarget: pendingSoilHumidityTarget,
        scheduleTimes: pendingScheduleTimes,
      );
      if (!mounted) return;
      setState(() {
        plantNames.add(normalizedName);
        plantIds[normalizedName] = id;
        plantName = normalizedName;
        plantModes[normalizedName] = irrigationMode;
        plantValve2Modes[normalizedName] = valve2Mode;
        plantFrequencies[normalizedName] = pendingFrequency;
        plantScheduleTimes[normalizedName] = pendingScheduleTimes;
        isLoading = false;
        isAddingPlant = false;
      });
      return;
    }
    setState(() {
      if (!plantNames.contains(normalizedName)) {
        plantNames.add(normalizedName);
      }
      plantName = normalizedName;
      plantModes[normalizedName] = irrigationMode;
      plantValve2Modes[normalizedName] = valve2Mode;
      plantFrequencies[normalizedName] = pendingFrequency;
      isLoading = false;
      isAddingPlant = false;
    });
    _savePlants();
    _savePlantConfigurations();
  }

  void _selectPlant(String name) {
    setState(() {
      plantName = name;
      irrigationMode = plantModes[name] ?? 'Inteligente';
      valve2Mode = plantValve2Modes[name] ?? 'Gotejamento';
    });
  }

  void _changeMode(String mode) {
    setState(() {
      irrigationMode = mode;
      plantModes[plantName] = mode;
    });
    _saveIrrigationMode(mode);
    _savePlantConfigurations();
    _saveRemoteConfiguration();
  }

  void _changeValve2(String value) {
    setState(() {
      valve2Mode = value;
      plantValve2Modes[plantName] = value;
    });
    _savePlantConfigurations();
    _saveRemoteConfiguration();
  }

  void _changeFrequency(String value) {
    setState(() => plantFrequencies[plantName] = value);
    _savePlantConfigurations();
    _saveRemoteConfiguration();
  }

  Future<void> _saveRemoteConfiguration() async {
    final id = plantIds[plantName];
    if (plantStore == null || id == null) return;
    await plantStore!.saveConfiguration(
      plantId: id,
      mode: irrigationMode,
      valve2Mode: valve2Mode,
      frequencyDays: int.tryParse(plantFrequencies[plantName] ?? '1') ?? 1,
    );
  }

  Future<void> _saveControlConfiguration(
    IrrigationControlConfiguration configuration,
  ) async {
    final id = plantIds[plantName];
    if (plantStore != null && id != null) {
      await plantStore!.saveConfiguration(
        plantId: id,
        mode: configuration.mode,
        valve2Mode: configuration.valve2Mode,
        frequencyDays: configuration.frequencyDays,
        finishMode: configuration.finishMode,
        durationSeconds: configuration.durationSeconds,
        soilTrigger: configuration.soilTrigger,
        soilHumidityTarget: configuration.soilHumidityTarget,
        scheduleTimes: configuration.scheduleTimes,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuração de irrigação salva.')),
    );
  }

  Future<void> editPlantName() async {
    final oldName = plantName;
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _EditPlantNameDialog(initialName: plantName),
    );
    if (newName == null || newName.isEmpty) return;
    setState(() {
      final index = plantNames.indexOf(plantName);
      if (index >= 0) plantNames[index] = newName;
      plantName = newName;
    });
    final id = plantIds[oldName];
    if (plantStore != null && id != null) {
      await plantStore!.renamePlant(id, newName);
    } else {
      await _savePlants();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: _background,
        body: Center(child: CircularProgressIndicator(color: _green)),
      );
    }

    if (plantNames.isEmpty || isAddingPlant) {
      return PlantSetupWizardScreen(
        onPlantCreated: addPlant,
        initialPlantName: '',
        skipEspSetup: false,
        onConfigurationSaved: (configuration) {
          setState(() {
            irrigationMode = configuration.mode;
            valve2Mode = configuration.valve2Mode;
            pendingFinishMode = configuration.finishMode;
            pendingDurationSeconds = configuration.durationSeconds;
            pendingSoilTrigger = configuration.soilTrigger;
            pendingSoilHumidityTarget = configuration.soilHumidityTarget;
            pendingScheduleTimes = configuration.scheduleTimes;
          });
          _saveIrrigationMode(configuration.mode);
        },
        onFrequencySaved: (frequency) => pendingFrequency = frequency,
      );
    }

    if (isEditingPlant) {
      return PlantSetupWizardScreen(
        onPlantCreated: _finishPlantEdit,
        initialPlantName: plantName,
        skipEspSetup: true,
        onConfigurationSaved: (configuration) {
          setState(() {
            irrigationMode = configuration.mode;
            valve2Mode = configuration.valve2Mode;
            pendingFinishMode = configuration.finishMode;
            pendingDurationSeconds = configuration.durationSeconds;
            pendingSoilTrigger = configuration.soilTrigger;
            pendingSoilHumidityTarget = configuration.soilHumidityTarget;
            pendingScheduleTimes = configuration.scheduleTimes;
          });
          _saveIrrigationMode(configuration.mode);
        },
        onFrequencySaved: _changeFrequency,
      );
    }

    final pages = [
      HomeDashboardScreenV2(
        plantName: plantName,
        plants: plantNames,
        irrigationMode: irrigationMode,
        valve2Mode: valve2Mode,
        onPlantSelected: _selectPlant,
        onEditName: editPlantName,
        onAddPlant: () => setState(() => isAddingPlant = true),
        onValve2Changed: _changeValve2,
      ),
      IrrigationControlMockScreen(
        plantName: plantName,
        plants: plantNames,
        initialMode: irrigationMode,
        initialValve2Mode: valve2Mode,
        initialFrequency: plantFrequencies[plantName] ?? '1',
        initialScheduleTimes: plantScheduleTimes[plantName] ?? const [],
        onPlantSelected: _selectPlant,
        onEditName: editPlantName,
        onAddPlant: () => setState(() => isAddingPlant = true),
        onModeChanged: _changeMode,
        onValve2Changed: _changeValve2,
        onFrequencyChanged: _changeFrequency,
        onSave: _saveControlConfiguration,
      ),
      HistoryMockScreen(
        plantName: plantName,
        plants: plantNames,
        plantId: plantIds[plantName],
        historyStore: historyStore,
        onPlantSelected: _selectPlant,
        onAddPlant: () => setState(() => isAddingPlant = true),
      ),
      PlantInfoMockScreen(
        plantName: plantName,
        plantId: plantIds[plantName],
        irrigationMode: irrigationMode,
        notificationStore: notificationStore,
        onSignOut: widget.useSupabase
            ? () => Supabase.instance.client.auth.signOut()
            : null,
        onEdit: () => setState(() => isEditingPlant = true),
        onRename: _renameSelectedPlant,
        onDelete: _deleteSelectedPlant,
        onResetEsp: _resetEspConfiguration,
      ),
    ];

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(child: pages[selectedIndex]),
      bottomNavigationBar: MockBottomNavigation(
        selectedIndex: selectedIndex,
        onSelected: (index) => setState(() => selectedIndex = index),
      ),
    );
  }

  Future<void> _renameSelectedPlant(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty || normalized == plantName) return;
    setState(() {
      final index = plantNames.indexOf(plantName);
      final id = plantIds.remove(plantName);
      if (index >= 0) plantNames[index] = normalized;
      final mode = plantModes.remove(plantName);
      final valve = plantValve2Modes.remove(plantName);
      final frequency = plantFrequencies.remove(plantName);
      final scheduleTimes = plantScheduleTimes.remove(plantName);
      if (mode != null) plantModes[normalized] = mode;
      if (valve != null) plantValve2Modes[normalized] = valve;
      if (frequency != null) plantFrequencies[normalized] = frequency;
      if (scheduleTimes != null) {
        plantScheduleTimes[normalized] = scheduleTimes;
      }
      if (id != null) plantIds[normalized] = id;
      plantName = normalized;
    });
    final id = plantIds[normalized];
    if (plantStore != null && id != null) {
      await plantStore!.renamePlant(id, normalized);
    } else {
      await _savePlants();
      await _savePlantConfigurations();
    }
  }

  Future<void> _finishPlantEdit(String name) async {
    await _renameSelectedPlant(name);
    setState(() => isEditingPlant = false);
  }

  Future<void> _deleteSelectedPlant() async {
    final id = plantIds[plantName];
    setState(() {
      plantNames.remove(plantName);
      plantModes.remove(plantName);
      plantValve2Modes.remove(plantName);
      plantFrequencies.remove(plantName);
      plantScheduleTimes.remove(plantName);
      plantIds.remove(plantName);
      plantName = plantNames.isEmpty ? '' : plantNames.first;
      if (plantName.isNotEmpty) {
        irrigationMode = plantModes[plantName] ?? 'Inteligente';
        valve2Mode = plantValve2Modes[plantName] ?? 'Gotejamento';
      }
      selectedIndex = 0;
    });
    if (plantStore != null && id != null) {
      await plantStore!.deletePlant(id);
    } else {
      await _savePlants();
      await _savePlantConfigurations();
    }
  }

  Future<void> _resetEspConfiguration() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('mock_esp_wifi_saved');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuração do ESP32 resetada.')),
    );
  }
}

class _EditPlantNameDialog extends StatefulWidget {
  const _EditPlantNameDialog({required this.initialName});
  final String initialName;

  @override
  State<_EditPlantNameDialog> createState() => _EditPlantNameDialogState();
}

class _EditPlantNameDialogState extends State<_EditPlantNameDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Editar nome da planta'),
    content: TextField(
      controller: controller,
      autofocus: true,
      maxLength: 32,
      decoration: const InputDecoration(labelText: 'Nome da planta'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text.trim()),
        child: const Text('Salvar'),
      ),
    ],
  );
}

class PlantSetupWizardScreen extends StatefulWidget {
  const PlantSetupWizardScreen({
    required this.onPlantCreated,
    required this.onConfigurationSaved,
    required this.onFrequencySaved,
    required this.initialPlantName,
    required this.skipEspSetup,
    super.key,
  });
  final Future<void> Function(String) onPlantCreated;
  final ValueChanged<PlantSetupConfiguration> onConfigurationSaved;
  final ValueChanged<String> onFrequencySaved;
  final String initialPlantName;
  final bool skipEspSetup;

  @override
  State<PlantSetupWizardScreen> createState() => _PlantSetupWizardScreenState();
}

class PlantSetupConfiguration {
  const PlantSetupConfiguration({
    required this.mode,
    required this.valve2Mode,
    required this.frequencyDays,
    required this.finishMode,
    required this.durationSeconds,
    required this.soilTrigger,
    required this.soilHumidityTarget,
    required this.scheduleTimes,
  });

  final String mode;
  final String valve2Mode;
  final int frequencyDays;
  final String finishMode;
  final int durationSeconds;
  final double soilTrigger;
  final double soilHumidityTarget;
  final List<ScheduleTimeInput> scheduleTimes;
}

class _PlantSetupWizardScreenState extends State<PlantSetupWizardScreen> {
  final popularController = TextEditingController();
  final scientificController = TextEditingController();
  final wifiController = TextEditingController();
  final passwordController = TextEditingController();
  final wateringTimeController = TextEditingController(text: '08:00');
  int step = 0;
  bool photoMode = true;
  bool aiSuggestionAccepted = true;
  bool paired = false;
  bool wifiSettingsOpened = false;
  bool espAccessPointConnected = false;
  bool wifiSaved = false;
  bool checkingEsp32 = false;
  bool scanningWifi = false;
  final esp32Service = Esp32LocalService();
  final scannedWifiNetworks = <Esp32WifiNetwork>[];
  String esp32BaseUrl = 'http://192.168.4.1';
  String selectedWifi = 'Minha Casa 2.4G';
  double light = 60;
  int wateringFrequency = 2;
  double irrigationDuration = 30;
  double soilTrigger = 35;
  double targetSoilMoisture = 50;
  String irrigationTarget = 'Duração';
  String valve2Mode = 'Gotejamento';
  bool isEditingIntelligent = false;
  final scheduleTimes = <String>['08:00', '18:00'];
  final scheduleDurations = <double>[30, 30];
  final scheduleValves = <String>['valve_2', 'valve_2'];
  String irrigationMode = 'Inteligente';
  int frequencyDays = 1;
  bool manualAutomaticStop = true;
  double manualDuration = 30;
  double manualSafetyTime = 120;

  @override
  void initState() {
    super.initState();
    if (widget.initialPlantName.isNotEmpty) {
      popularController.text = widget.initialPlantName;
      photoMode = false;
    }
  }

  @override
  void dispose() {
    popularController.dispose();
    scientificController.dispose();
    wifiController.dispose();
    passwordController.dispose();
    wateringTimeController.dispose();
    super.dispose();
  }

  String get plantName => photoMode
      ? (popularController.text.trim().isEmpty
            ? 'Minha planta'
            : popularController.text.trim())
      : popularController.text.trim();

  String _validFinishMode(String value) =>
      value == 'Duração' || value == 'Umidade' ? value : 'Duração';

  PlantSetupConfiguration get configuration => PlantSetupConfiguration(
    mode: aiSuggestionAccepted ? 'Inteligente' : irrigationMode,
    valve2Mode: valve2Mode,
    frequencyDays: frequencyDays,
    finishMode: irrigationTarget,
    durationSeconds: irrigationDuration.round(),
    soilTrigger: soilTrigger,
    soilHumidityTarget: targetSoilMoisture,
    scheduleTimes: [
      for (var index = 0; index < scheduleTimes.length; index++)
        ScheduleTimeInput(
          timeOfDay: scheduleTimes[index],
          durationSeconds: scheduleDurations[index].round(),
          valve: scheduleValves[index],
        ),
    ],
  );

  Future<void> _connectToEsp32() async {
    setState(() => checkingEsp32 = true);
    final discoveredUrl = await esp32Service.discoverByMdns();
    if (discoveredUrl != null) esp32BaseUrl = discoveredUrl;
    final connected = await esp32Service.isReachable(baseUrl: esp32BaseUrl);
    if (!mounted) return;
    setState(() {
      checkingEsp32 = false;
      espAccessPointConnected = connected;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          connected
              ? 'ESP32 encontrado em $esp32BaseUrl.'
              : 'Não foi possível encontrar o ESP32. Conecte o celular ao Wi-Fi Irrigacao_Setup_XXXX e tente novamente.',
        ),
      ),
    );
    if (connected) await _scanEsp32Networks();
  }

  Future<void> _scanEsp32Networks() async {
    setState(() => scanningWifi = true);
    try {
      final networks = await esp32Service.scanNetworks(baseUrl: esp32BaseUrl);
      if (!mounted) return;
      setState(() {
        scannedWifiNetworks
          ..clear()
          ..addAll(networks);
        if (networks.isNotEmpty) selectedWifi = networks.first.ssid;
        scanningWifi = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => scanningWifi = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível buscar as redes: $error')),
      );
    }
  }

  Future<void> _saveEsp32Network() async {
    if (selectedWifi.trim().isEmpty) return;
    setState(() => scanningWifi = true);
    try {
      await esp32Service.configureNetwork(
        baseUrl: esp32BaseUrl,
        ssid: selectedWifi,
        password: passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        wifiSaved = true;
        scanningWifi = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rede enviada ao ESP32. Ele irá reiniciar e conectar-se à rede escolhida.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => scanningWifi = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível configurar o ESP32: $error')),
      );
    }
  }

  void nextStep() {
    if (step == 0 && plantName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o nome da planta ou selecione uma foto.'),
        ),
      );
      return;
    }
    if (widget.skipEspSetup && step == 1) {
      widget.onConfigurationSaved(configuration);
      widget.onFrequencySaved(frequencyDays.toString());
      widget.onPlantCreated(plantName);
    } else if (step < 2) {
      setState(() => step++);
    } else {
      if (!wifiSaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Salve a rede Wi-Fi antes de concluir a configuração.',
            ),
          ),
        );
        return;
      }
      widget.onConfigurationSaved(configuration);
      widget.onFrequencySaved(frequencyDays.toString());
      widget.onPlantCreated(plantName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastStep = widget.skipEspSetup ? 1 : 2;
    final titles = [
      'Escolha sua planta',
      'Cuidados da planta',
      'Conecte o ESP',
    ];
    final descriptions = [
      'Identifique a planta por foto ou informe seus nomes.',
      'Aceite a sugestão simulada da IA ou personalize os parâmetros.',
      'Configure a rede e pareie o dispositivo antes de continuar.',
    ];
    final stepContent = step == 0
        ? _buildSelectionContent()
        : step == 1
        ? _buildPlantParameters()
        : _buildEspSetupV2();
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: (step == 0
                        ? null
                        : () => setState(() => step--)),
                    icon: const Icon(Icons.arrow_back_rounded, color: _green),
                  ),
                  const Spacer(),
                  Text(
                    'Etapa ${step + 1} de ${lastStep + 1}',
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var index = 0; index <= lastStep; index++)
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                        height: 6,
                        decoration: BoxDecoration(
                          color: index <= step ? _green : Colors.black12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                titles[step],
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(color: _greenDark, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                descriptions[step],
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 26),
              stepContent,
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: nextStep,
                  icon: Icon(
                    step == 2
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                  ),
                  label: Text(
                    step == lastStep
                        ? (widget.skipEspSetup
                              ? 'Salvar alteração'
                              : 'Concluir configuração')
                        : 'Continuar',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* Widget _buildPlantSelection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _ChoiceButton(label: 'Enviar foto', icon: Icons.camera_alt_outlined, selected: photoMode, onTap: () => setState(() => photoMode = true))),
          const SizedBox(width: 12),
          Expanded(child: _ChoiceButton(label: 'Buscar nome', icon: Icons.search_rounded, selected: !photoMode, onTap: () => setState(() => photoMode = false))),
        ]),
        const SizedBox(height: 20),
         _buildSelectionContent(), if (photoMode)
          InkWell(onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto selecionada para identificação simulada.'))), borderRadius: BorderRadius.circular(24), child: Container(height: 210, width: double.infinity, decoration: BoxDecoration(color: _mint, borderRadius: BorderRadius.circular(24), border: Border.all(color: _green.withValues(alpha: .2))), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, color: _green, size: 50), SizedBox(height: 12), Text('Toque para enviar uma foto', style: TextStyle(color: _green, fontWeight: FontWeight.w700)), SizedBox(height: 6), Text('A identificação será simulada nesta etapa', style: TextStyle(color: Colors.black54))])))
         else ...[
          _TextField(label: 'Nome popular', hint: 'Ex.: Manjericão', controller: popularController),
          const SizedBox(height: 14),
          _TextField(label: 'Nome científico', hint: 'Ex.: Ocimum basilicum', controller: scientificController),
        ],
      ]);

  */
  Widget _buildSelectionContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: _ChoiceButton(
              label: 'Enviar foto',
              icon: Icons.camera_alt_outlined,
              selected: photoMode,
              onTap: () => setState(() => photoMode = true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ChoiceButton(
              label: 'Buscar nome',
              icon: Icons.search_rounded,
              selected: !photoMode,
              onTap: () => setState(() => photoMode = false),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      if (photoMode)
        InkWell(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto selecionada para identificação simulada.'),
            ),
          ),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 210,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _mint,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _green.withValues(alpha: .2)),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, color: _green, size: 50),
                SizedBox(height: 12),
                Text(
                  'Toque para enviar uma foto',
                  style: TextStyle(color: _green, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  'A identificação será simulada nesta etapa',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      if (!photoMode) ...[
        _TextField(
          label: 'Nome popular',
          hint: 'Ex.: Manjericão',
          controller: popularController,
        ),
        const SizedBox(height: 14),
        _TextField(
          label: 'Nome científico',
          hint: 'Ex.: Ocimum basilicum',
          controller: scientificController,
        ),
      ],
    ],
  );

  Widget _buildPlantParameters() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!aiSuggestionAccepted) ...[
        _buildManualParametersV2(),
      ] else ...[
        _WizardCard(
          icon: Icons.auto_awesome,
          title: 'Sugestão da IA',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Manjericão • luz indireta intensa',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Gotejamento por 30 segundos quando o solo estiver abaixo de 35%.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 6),
              Text(
                'Frequência sugerida: a cada $frequencyDays dia(s), '
                '$wateringFrequency rega(s) por dia.',
                style: const TextStyle(color: Colors.black54),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aceitar recomendação'),
                value: aiSuggestionAccepted,
                onChanged: (value) => setState(() {
                  aiSuggestionAccepted = value;
                  if (!value && irrigationMode == 'Inteligente') {
                    irrigationMode = 'Programado';
                  }
                }),
              ),
            ],
          ),
        ),
        if (!aiSuggestionAccepted) ...[
          const SizedBox(height: 14),
          _WizardCard(
            icon: Icons.water_drop_outlined,
            title: 'Modo de irrigação',
            child: DropdownButtonFormField<String>(
              initialValue: irrigationMode,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Manual', child: Text('Manual')),
                DropdownMenuItem(
                  value: 'Programado',
                  child: Text('Programado'),
                ),
                DropdownMenuItem(
                  value: 'Inteligente',
                  child: Text('Inteligente'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => irrigationMode = value ?? irrigationMode),
            ),
          ),
          const SizedBox(height: 14),
          _WizardCard(
            icon: Icons.wb_sunny_outlined,
            title: 'Quantidade de luz ideal',
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Luminosidade'),
                    Text(
                      '${light.round()}%',
                      style: const TextStyle(
                        color: _green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: light,
                  min: 0,
                  max: 100,
                  activeColor: _green,
                  onChanged: (value) => setState(() => light = value),
                ),
              ],
            ),
          ),
        ],
      ],
    ],
  );

  // Kept as a reference for the first mock iteration.
  // ignore: unused_element
  Widget _buildManualParameters() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _WizardCard(
        icon: Icons.tune_rounded,
        title: 'Personalizar cuidados',
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Utilizar sugestão da IA'),
              subtitle: const Text(
                'Ative para voltar às configurações sugeridas.',
              ),
              value: aiSuggestionAccepted,
              onChanged: (value) =>
                  setState(() => aiSuggestionAccepted = value),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: irrigationMode,
              decoration: const InputDecoration(
                labelText: 'Modo de irrigação',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Manual', child: Text('Manual')),
                DropdownMenuItem(
                  value: 'Programado',
                  child: Text('Programado'),
                ),
                DropdownMenuItem(
                  value: 'Inteligente',
                  child: Text('Inteligente'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => irrigationMode = value ?? irrigationMode),
            ),
            const SizedBox(height: 14),
            _TextField(
              label: 'Horário da rega',
              hint: 'Ex.: 08:00',
              controller: wateringTimeController,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _validFinishMode(irrigationTarget),
              decoration: const InputDecoration(
                labelText: 'A irrigação termina por',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Duração',
                  child: Text('Duração definida'),
                ),
                DropdownMenuItem(
                  value: 'Umidade',
                  child: Text('Até atingir a umidade do solo'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => irrigationTarget = value ?? irrigationTarget),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Irrigações por dia: $wateringFrequency',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: wateringFrequency <= 1
                      ? null
                      : () => setState(() => wateringFrequency--),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  onPressed: () => setState(() => wateringFrequency++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (irrigationTarget == 'Duração') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Duração de cada irrigação'),
                  Text(
                    '${irrigationDuration.round()} s',
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Slider(
                value: irrigationDuration,
                min: 5,
                max: 300,
                divisions: 59,
                activeColor: _green,
                onChanged: (value) =>
                    setState(() => irrigationDuration = value),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Umidade alvo do solo'),
                  Text(
                    '${soilTrigger.round()}%',
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Slider(
                value: soilTrigger,
                min: 20,
                max: 90,
                divisions: 70,
                activeColor: _green,
                onChanged: (value) => setState(() => soilTrigger = value),
              ),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Luz necessária'),
                Text(
                  '${light.round()}%',
                  style: const TextStyle(
                    color: _green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Slider(
              value: light,
              min: 0,
              max: 100,
              activeColor: _green,
              onChanged: (value) => setState(() => light = value),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Gatilho: irrigar abaixo de'),
                Text(
                  '${soilTrigger.round()}%',
                  style: const TextStyle(
                    color: _green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Slider(
              value: soilTrigger,
              min: 10,
              max: 80,
              divisions: 70,
              activeColor: _green,
              onChanged: (value) => setState(() => soilTrigger = value),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildManualParametersV2() {
    final details = switch (irrigationMode) {
      'Manual' => _buildManualSafetySetup(),
      'Programado' => _buildProgrammedEditorContent(),
      _ => _buildIntelligentEditorContent(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WizardCard(
          icon: Icons.auto_awesome,
          title: 'Ativar novamente',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Utilizar sugestão da IA'),
            subtitle: const Text(
              'Ative para voltar às configurações sugeridas.',
            ),
            value: aiSuggestionAccepted,
            onChanged: (value) => setState(() {
              aiSuggestionAccepted = value;
              if (!value && irrigationMode == 'Inteligente') {
                irrigationMode = 'Programado';
              }
            }),
          ),
        ),
        const SizedBox(height: 14),
        _WizardCard(
          icon: Icons.water_drop_outlined,
          title: 'Modelo de irrigação',
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: irrigationMode,
                decoration: const InputDecoration(
                  labelText: 'Modo de irrigação',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Manual', child: Text('Manual')),
                  DropdownMenuItem(
                    value: 'Programado',
                    child: Text('Programado'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => irrigationMode = value ?? irrigationMode),
              ),
              if (irrigationMode != 'Manual') ...[
                const SizedBox(height: 14),
                _ValveVerticalSummary(
                  valve2Mode: valve2Mode,
                  onEdit: _editSetupValve2,
                ),
                const SizedBox(height: 14),
                details,
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSetupLightCard(),
      ],
    );
  }

  Widget _buildSetupLightCard() => _WizardCard(
    icon: Icons.wb_sunny_outlined,
    title: 'Quantidade de luz ideal',
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Luminosidade'),
            Text(
              '${light.round()}%',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          value: light,
          min: 0,
          max: 100,
          activeColor: _green,
          onChanged: (value) => setState(() => light = value),
        ),
      ],
    ),
  );

  Widget _buildManualSafetySetup() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Segurança da irrigação manual',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Desativação automática'),
        subtitle: Text(
          manualAutomaticStop
              ? 'A válvula será fechada ao fim do tempo escolhido.'
              : 'Usa um tempo máximo de segurança caso o app seja fechado.',
        ),
        value: manualAutomaticStop,
        onChanged: (value) => setState(() => manualAutomaticStop = value),
      ),
      _NumericDurationField(
        value: manualAutomaticStop ? manualDuration : manualSafetyTime,
        onChanged: (value) => setState(() {
          if (manualAutomaticStop) {
            manualDuration = value;
          } else {
            manualSafetyTime = value;
          }
        }),
      ),
      if (!manualAutomaticStop)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Ao atingir esse tempo, a bomba será desligada e uma notificação será gerada.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ),
    ],
  );

  Future<void> _editSetupValve2() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Escolha a Válvula 2'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Gotejamento'),
            child: const Text('Gotejamento'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Microaspersão'),
            child: const Text('Microaspersão'),
          ),
        ],
      ),
    );
    if (selected != null) setState(() => valve2Mode = selected);
  }

  Widget _buildProgrammedEditorContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSetupFrequencySelector(),
      const SizedBox(height: 12),
      Text(
        'Quantidade de vezes ao dia: ${scheduleTimes.length}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      ...List.generate(
        scheduleTimes.length,
        (index) => _buildScheduleRow(index),
      ),
      if (scheduleTimes.length < 6)
        TextButton.icon(
          onPressed: () => setState(() {
            scheduleTimes.add('12:00');
            scheduleDurations.add(30);
            scheduleValves.add('valve_2');
          }),
          icon: const Icon(Icons.add),
          label: const Text('Adicionar horário'),
        ),
      const Divider(height: 24),
      DropdownButtonFormField<String>(
        initialValue: _validFinishMode(irrigationTarget),
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'A irrigação termina por',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(
            value: 'Duração',
            child: Text(
              'Duração individual por horário',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DropdownMenuItem(
            value: 'Umidade',
            child: Text(
              'Até atingir a umidade do solo',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        onChanged: (value) =>
            setState(() => irrigationTarget = value ?? irrigationTarget),
      ),
      if (irrigationTarget == 'Umidade') ...[
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Iniciar irrigação abaixo de'),
            Text(
              'Abaixo de ${soilTrigger.round()}%',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          value: soilTrigger,
          min: 10,
          max: 80,
          divisions: 70,
          activeColor: _green,
          onChanged: (value) => setState(() => soilTrigger = value),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Finalizar ao atingir'),
            Text(
              '${targetSoilMoisture.round()}%',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          value: targetSoilMoisture,
          min: 20,
          max: 95,
          divisions: 75,
          activeColor: _green,
          onChanged: (value) => setState(() => targetSoilMoisture = value),
        ),
      ],
    ],
  );

  Widget _buildScheduleRow(int index) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Rega ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _selectScheduleTime(index),
              icon: const Icon(Icons.access_time, size: 18),
              label: Text(scheduleTimes[index]),
            ),
            if (scheduleTimes.length > 1)
              IconButton(
                onPressed: () => setState(() {
                  scheduleTimes.removeAt(index);
                  scheduleDurations.removeAt(index);
                  scheduleValves.removeAt(index);
                }),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
          ],
        ),
        if (irrigationTarget == 'Duração')
          _NumericDurationField(
            value: scheduleDurations[index],
            onChanged: (value) =>
                setState(() => scheduleDurations[index] = value),
          ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _validValve(scheduleValves[index]),
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Válvula utilizada nesta rega',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(
              value: 'valve_1',
              child: Text(
                'Válvula 1 — Nebulização',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'valve_2',
              child: Text(
                'Válvula 2 — $valve2Mode',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => scheduleValves[index] = value);
          },
        ),
      ],
    ),
  );

  String _validValve(String value) =>
      value == 'valve_1' || value == 'valve_2' ? value : 'valve_2';

  Future<void> _selectScheduleTime(int index) async {
    final parts = scheduleTimes[index].split(':');
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (selected == null) return;
    setState(
      () => scheduleTimes[index] =
          '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}',
    );
  }

  Widget _buildIntelligentEditorContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSetupFrequencySelector(),
      const SizedBox(height: 12),
      _buildSetupDailyWateringsSelector(),
      const SizedBox(height: 10),
      ...List.generate(
        scheduleTimes.length,
        (index) => _buildScheduleRow(index),
      ),
      const SizedBox(height: 14),
      const Text(
        'A IA sugeriu irrigação por gotejamento.',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      const Text(
        'Você pode ajustar os valores antes de salvar.',
        style: TextStyle(color: Colors.black54),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: _validFinishMode(irrigationTarget),
        decoration: const InputDecoration(
          labelText: 'Finalizar irrigação por',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'Duração', child: Text('Duração')),
          DropdownMenuItem(value: 'Umidade', child: Text('Umidade do solo')),
        ],
        onChanged: (value) =>
            setState(() => irrigationTarget = value ?? irrigationTarget),
      ),
      const SizedBox(height: 14),
      if (irrigationTarget == 'Duração')
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Duração sugerida'),
            Text(
              '${irrigationDuration.round()} segundos',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      if (irrigationTarget == 'Duração')
        _NumericDurationField(
          value: irrigationDuration,
          onChanged: (value) => setState(() => irrigationDuration = value),
        ),
      if (irrigationTarget == 'Umidade')
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Iniciar irrigação abaixo de'),
            Text(
              'Abaixo de ${soilTrigger.round()}%',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      if (irrigationTarget == 'Umidade')
        Slider(
          value: soilTrigger,
          min: 10,
          max: 80,
          divisions: 70,
          activeColor: _green,
          onChanged: (value) => setState(() => soilTrigger = value),
        ),
      if (irrigationTarget == 'Umidade') ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Finalizar ao atingir'),
            Text(
              '${targetSoilMoisture.round()}%',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          value: targetSoilMoisture,
          min: 20,
          max: 95,
          divisions: 75,
          activeColor: _green,
          onChanged: (value) => setState(() => targetSoilMoisture = value),
        ),
      ],
    ],
  );

  Widget _buildSetupFrequencySelector() => TextFormField(
    keyboardType: TextInputType.number,
    initialValue: frequencyDays.toString(),
    decoration: const InputDecoration(
      labelText: 'Intervalo entre regas',
      prefixText: 'A cada ',
      suffixText: ' dia(s)',
      border: OutlineInputBorder(),
    ),
    onChanged: (value) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        setState(() => frequencyDays = parsed.clamp(1, 30));
      }
    },
  );

  Widget _buildSetupDailyWateringsSelector() => Row(
    children: [
      Expanded(
        child: Text(
          'Regas por dia: $wateringFrequency',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      IconButton(
        onPressed: wateringFrequency <= 1
            ? null
            : () => _changeSetupWateringCount(wateringFrequency - 1),
        icon: const Icon(Icons.remove_circle_outline),
      ),
      IconButton(
        onPressed: wateringFrequency >= 6
            ? null
            : () => _changeSetupWateringCount(wateringFrequency + 1),
        icon: const Icon(Icons.add_circle_outline),
      ),
    ],
  );

  void _changeSetupWateringCount(int count) {
    setState(() {
      wateringFrequency = count.clamp(1, 6);
      while (scheduleTimes.length < wateringFrequency) {
        scheduleTimes.add('12:00');
        scheduleDurations.add(30);
        scheduleValves.add('valve_2');
      }
      while (scheduleTimes.length > wateringFrequency) {
        scheduleTimes.removeLast();
        scheduleDurations.removeLast();
        scheduleValves.removeLast();
      }
    });
  }

  Widget _buildEspSetupV2() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _WizardCard(
        icon: Icons.phone_android_rounded,
        title: 'Passo 1 — Abra as redes Wi-Fi',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Abra as configurações de Wi-Fi do celular para encontrar o ponto de acesso temporário do ESP32.',
              style: TextStyle(color: Colors.black54, height: 1.35),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(() => wifiSettingsOpened = true),
              icon: const Icon(Icons.wifi_rounded),
              label: Text(
                wifiSettingsOpened
                    ? 'Configurações de Wi-Fi abertas'
                    : 'Abrir configurações de Wi-Fi',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _WizardCard(
        icon: Icons.router_rounded,
        title: 'Passo 2 — Conecte ao ESP32',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nas redes disponíveis, selecione o ponto de acesso criado pelo dispositivo:',
              style: TextStyle(color: Colors.black54, height: 1.35),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _mint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Irrigacao_Setup_XXXX',
                style: TextStyle(color: _green, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: wifiSettingsOpened
                  ? (checkingEsp32 ? null : _connectToEsp32)
                  : null,
              icon: Icon(
                checkingEsp32
                    ? Icons.sync
                    : espAccessPointConnected
                    ? Icons.check_circle
                    : Icons.link_rounded,
              ),
              label: Text(
                checkingEsp32
                    ? 'Procurando ESP32...'
                    : espAccessPointConnected
                    ? 'ESP32 conectado'
                    : 'Confirmar conexão com o ESP32',
              ),
            ),
          ],
        ),
      ),
      if (espAccessPointConnected) ...[
        const SizedBox(height: 14),
        _WizardCard(
          icon: Icons.wifi_rounded,
          title: 'Passo 3 — Escolha a rede residencial',
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedWifi,
                decoration: const InputDecoration(
                  labelText: 'Rede Wi-Fi do ESP32',
                  border: OutlineInputBorder(),
                ),
                items: scannedWifiNetworks.isEmpty
                    ? const [
                        DropdownMenuItem(
                          value: 'Minha Casa 2.4G',
                          child: Text('Busque as redes disponíveis'),
                        ),
                      ]
                    : [
                        for (final network in scannedWifiNetworks)
                          DropdownMenuItem(
                            value: network.ssid,
                            child: Text(network.ssid),
                          ),
                      ],
                onChanged: (value) => setState(() {
                  selectedWifi = value ?? selectedWifi;
                  wifiSaved = false;
                }),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: scanningWifi ? null : _scanEsp32Networks,
                  icon: const Icon(Icons.refresh),
                  label: Text(scanningWifi ? 'Buscando redes...' : 'Buscar redes próximas'),
                ),
              ),
              const SizedBox(height: 14),
              _TextField(
                label: 'Senha da rede',
                hint: 'Digite a senha do Wi-Fi',
                controller: passwordController,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: scanningWifi ? null : _saveEsp32Network,
                  icon: Icon(wifiSaved ? Icons.check : Icons.save_outlined),
                  label: Text(
                    wifiSaved ? 'Configuração salva' : 'Salvar rede no ESP32',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );

  // Mantido como referência da primeira versão visual.
  // ignore: unused_element
  Widget _buildEspSetup() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _WizardCard(
        icon: Icons.wifi_rounded,
        title: 'Rede Wi-Fi do ESP32',
        child: Column(
          children: [
            _TextField(
              label: 'Nome da rede',
              hint: 'Ex.: Minha Casa 2.4G',
              controller: wifiController,
            ),
            const SizedBox(height: 14),
            _TextField(
              label: 'Senha da rede',
              hint: 'Digite a senha do Wi-Fi',
              controller: passwordController,
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _WizardCard(
        icon: Icons.link_rounded,
        title: 'Pareamento',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              paired
                  ? 'ESP32 conectado e pronto para uso.'
                  : 'Aproxime o ESP32 e inicie o pareamento.',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(() => paired = true),
              icon: Icon(paired ? Icons.check : Icons.bluetooth_searching),
              label: Text(
                paired ? 'Dispositivo pareado' : 'Parear dispositivo',
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ValveDescription extends StatelessWidget {
  const _ValveDescription({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.water_drop_outlined, color: _green, size: 20),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
      Text(
        value,
        style: const TextStyle(color: _green, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _WizardCard extends StatelessWidget {
  const _WizardCard({
    required this.icon,
    required this.title,
    required this.child,
    this.headerAction,
  });
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? headerAction;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _greenDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            ...headerAction == null ? <Widget>[] : <Widget>[headerAction!],
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class PlantSetupScreen extends StatefulWidget {
  const PlantSetupScreen({required this.onPlantCreated, super.key});
  final ValueChanged<String> onPlantCreated;

  @override
  State<PlantSetupScreen> createState() => _PlantSetupScreenState();
}

class _PlantSetupScreenState extends State<PlantSetupScreen> {
  final popularController = TextEditingController();
  final scientificController = TextEditingController();
  bool photoMode = true;

  @override
  void dispose() {
    popularController.dispose();
    scientificController.dispose();
    super.dispose();
  }

  void createPlant() {
    if (!photoMode && popularController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe pelo menos o nome popular da planta.'),
        ),
      );
      return;
    }
    final name = photoMode ? 'Minha planta' : popularController.text.trim();
    widget.onPlantCreated(name);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 42, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.spa_rounded, color: _green, size: 42),
            const SizedBox(height: 24),
            Text(
              'Vamos começar sua\nhorta inteligente',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: _greenDark, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              'Cadastre sua primeira planta para acompanhar a umidade, temperatura e as próximas irrigações.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: Colors.black54, height: 1.45),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _ChoiceButton(
                    label: 'Adicionar por foto',
                    icon: Icons.camera_alt_outlined,
                    selected: photoMode,
                    onTap: () => setState(() => photoMode = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ChoiceButton(
                    label: 'Adicionar manualmente',
                    icon: Icons.edit_outlined,
                    selected: !photoMode,
                    onTap: () => setState(() => photoMode = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (photoMode) ...[
              Container(
                height: 230,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _mint,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _green.withValues(alpha: .18)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'A seleção de foto será conectada na próxima etapa.',
                      ),
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: _green, size: 52),
                      SizedBox(height: 12),
                      Text(
                        'Toque para escolher uma foto',
                        style: TextStyle(
                          color: _green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Usaremos a imagem para identificar sua planta',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              _TextField(
                label: 'Nome popular',
                hint: 'Ex.: Manjericão',
                controller: popularController,
              ),
              const SizedBox(height: 16),
              _TextField(
                label: 'Nome científico (opcional)',
                hint: 'Ex.: Ocimum basilicum',
                controller: scientificController,
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: createPlant,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continuar'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: selected ? _green : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? _green : Colors.black12),
      ),
      child: Column(
        children: [
          Icon(icon, color: selected ? Colors.white : _green),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : _greenDark,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.label,
    required this.hint,
    required this.controller,
  });
  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.black12),
      ),
    ),
  );
}

class _NumericDurationField extends StatelessWidget {
  const _NumericDurationField({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: value.round().toString(),
    keyboardType: TextInputType.number,
    decoration: const InputDecoration(
      labelText: 'Duração (segundos)',
      suffixText: 's',
      border: OutlineInputBorder(),
    ),
    onChanged: (text) {
      final parsed = double.tryParse(text);
      if (parsed != null) onChanged(parsed.clamp(1, 3600).toDouble());
    },
  );
}

class HomeMockScreen extends StatelessWidget {
  const HomeMockScreen({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          decoration: const BoxDecoration(
            color: _greenDark,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dashboard –\nHorta Varanda',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    onPressed: () => showNotificationDrawer(context),
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.spa_outlined, color: Colors.white, size: 25),
                    SizedBox(width: 12),
                    Text(
                      'Horta Varanda',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.circle, color: Color(0xFF2DDB96), size: 11),
                    SizedBox(width: 6),
                    Text(
                      'Online',
                      style: TextStyle(
                        color: Color(0xFF2DDB96),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.wifi_tethering, color: Colors.white, size: 19),
                  SizedBox(width: 8),
                  Text(
                    'Monitoramento em tempo real',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC247),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.black,
                      size: 34,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Nível de água baixo no reservatório.\nReabasteça para não interromper as irrigações.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.water_drop_outlined,
                      title: 'Umidade do solo',
                      value: '62%',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.thermostat_outlined,
                      title: 'Temperatura',
                      value: '24°C',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.cloud_outlined,
                      title: 'Umidade do ar',
                      value: '68%',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.wb_sunny_outlined,
                      title: 'Luz',
                      value: '8.420',
                      suffix: ' lux',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const _MetricCard(
                icon: Icons.calendar_month_outlined,
                title: 'Próxima rega',
                value: 'hoje às 18:00',
                wide: true,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    this.suffix = '',
    this.wide = false,
  });
  final IconData icon;
  final String title;
  final String value;
  final String suffix;
  final bool wide;

  @override
  Widget build(BuildContext context) => Container(
    width: wide ? double.infinity : null,
    height: 104,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(color: _mint, shape: BoxShape.circle),
          child: Icon(icon, color: _green, size: 29),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: _green,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                  children: [
                    TextSpan(text: value),
                    TextSpan(
                      text: suffix,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class MockBottomNavigation extends StatelessWidget {
  const MockBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => NavigationBar(
    height: 64,
    selectedIndex: selectedIndex,
    onDestinationSelected: onSelected,
    backgroundColor: _greenDark,
    indicatorColor: _green,
    labelTextStyle: const WidgetStatePropertyAll(
      TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
    ),
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined, color: Colors.white),
        selectedIcon: Icon(Icons.home, color: Colors.white),
        label: 'Início',
      ),
      NavigationDestination(
        icon: Icon(Icons.water_drop_outlined, color: Colors.white),
        selectedIcon: Icon(Icons.water_drop, color: Colors.white),
        label: 'Controle',
      ),
      NavigationDestination(
        icon: Icon(Icons.history_outlined, color: Colors.white),
        selectedIcon: Icon(Icons.history, color: Colors.white),
        label: 'Histórico',
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined, color: Colors.white),
        selectedIcon: Icon(Icons.settings, color: Colors.white),
        label: 'Config',
      ),
    ],
  );
}

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({
    required this.plantName,
    required this.plants,
    required this.irrigationMode,
    required this.valve2Mode,
    required this.onPlantSelected,
    required this.onEditName,
    required this.onAddPlant,
    super.key,
  });
  final String plantName;
  final List<String> plants;
  final String irrigationMode;
  final String valve2Mode;
  final ValueChanged<String> onPlantSelected;
  final VoidCallback onEditName;
  final VoidCallback onAddPlant;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          decoration: const BoxDecoration(
            color: _greenDark,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dashboard –\n$plantName',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    onPressed: () => showNotificationDrawer(context),
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 8,
                  top: 4,
                  bottom: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.spa_outlined,
                      color: Colors.white,
                      size: 25,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: plantName,
                          isExpanded: true,
                          dropdownColor: _greenDark,
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          items: [
                            ...plants.map(
                              (name) => DropdownMenuItem(
                                value: name,
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const DropdownMenuItem(
                              value: '__add__',
                              child: Text(
                                '+ Adicionar planta',
                                style: TextStyle(
                                  color: Color(0xFF7FF2B6),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == '__add__') {
                              onAddPlant();
                            } else if (value != null) {
                              onPlantSelected(value);
                            }
                          },
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onEditName,
                      tooltip: 'Editar nome',
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                    const Icon(
                      Icons.circle,
                      color: Color(0xFF2DDB96),
                      size: 11,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Online',
                      style: TextStyle(
                        color: Color(0xFF2DDB96),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Icon(Icons.wifi_tethering, color: Colors.white, size: 19),
                  SizedBox(width: 8),
                  Text(
                    'Monitoramento em tempo real',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (_showWaterAlert) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC247),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.black,
                        size: 34,
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Nível de água baixo no reservatório.\nReabasteça para não interromper as irrigações.',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.water_drop_outlined,
                      title: 'Umidade do solo',
                      value: '62%',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.thermostat_outlined,
                      title: 'Temperatura',
                      value: '24°C',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.cloud_outlined,
                      title: 'Umidade do ar',
                      value: '68%',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.wb_sunny_outlined,
                      title: 'Luz',
                      value: '8.420',
                      suffix: ' lux',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const _MetricCard(
                icon: Icons.calendar_month_outlined,
                title: 'Próxima rega',
                value: 'hoje às 18:00',
                wide: true,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class HomeDashboardScreenV2 extends StatelessWidget {
  const HomeDashboardScreenV2({
    required this.plantName,
    required this.plants,
    required this.irrigationMode,
    required this.valve2Mode,
    required this.onPlantSelected,
    required this.onEditName,
    required this.onAddPlant,
    required this.onValve2Changed,
    super.key,
  });
  final String plantName;
  final List<String> plants;
  final String irrigationMode;
  final String valve2Mode;
  final ValueChanged<String> onPlantSelected;
  final VoidCallback onEditName;
  final VoidCallback onAddPlant;
  final ValueChanged<String> onValve2Changed;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          decoration: const BoxDecoration(
            color: _greenDark,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dashboard – $plantName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () => showNotificationDrawer(context),
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 8,
                  top: 4,
                  bottom: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.spa_outlined,
                      color: Colors.white,
                      size: 25,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: plantName,
                          isExpanded: true,
                          dropdownColor: _greenDark,
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          items: [
                            ...plants.map(
                              (name) => DropdownMenuItem(
                                value: name,
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const DropdownMenuItem(
                              value: '__add__',
                              child: Text(
                                '+ Adicionar planta',
                                style: TextStyle(
                                  color: Color(0xFF7FF2B6),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == '__add__') {
                              onAddPlant();
                            } else if (value != null) {
                              onPlantSelected(value);
                            }
                          },
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onEditName,
                      tooltip: 'Editar nome',
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                    const Icon(
                      Icons.circle,
                      color: Color(0xFF2DDB96),
                      size: 11,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Online',
                      style: TextStyle(
                        color: Color(0xFF2DDB96),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Icon(Icons.wifi_tethering, color: Colors.white, size: 19),
                  SizedBox(width: 8),
                  Text(
                    'Monitoramento em tempo real',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.water_drop_outlined,
                    color: Colors.white,
                    size: 19,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Modo irrigação: ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    irrigationMode,
                    style: TextStyle(
                      color: Color(0xFF7FF2B6),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (irrigationMode == 'Manual') ...[
                const SizedBox(height: 14),
                _ManualHomeControls(
                  valve2Mode: valve2Mode,
                  onValve2Changed: onValve2Changed,
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            children: [
              const _MetricCard(
                icon: Icons.water_drop_outlined,
                title: 'Umidade do solo',
                value: '62%',
                wide: true,
              ),
              const SizedBox(height: 10),
              const _MetricCard(
                icon: Icons.thermostat_outlined,
                title: 'Temperatura',
                value: '24°C',
                wide: true,
              ),
              const SizedBox(height: 10),
              const _MetricCard(
                icon: Icons.cloud_outlined,
                title: 'Umidade do ar',
                value: '68%',
                wide: true,
              ),
              const SizedBox(height: 10),
              const _MetricCard(
                icon: Icons.wb_sunny_outlined,
                title: 'Luz',
                value: '8.420',
                suffix: ' lux',
                wide: true,
              ),
              const SizedBox(height: 10),
              const _MetricCard(
                icon: Icons.calendar_month_outlined,
                title: 'Próxima rega',
                value: 'hoje às 18:00',
                wide: true,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ControlPlantHeader extends StatelessWidget {
  const _ControlPlantHeader({
    required this.plantName,
    required this.plants,
    required this.onPlantSelected,
    required this.onEditName,
    required this.onAddPlant,
  });
  final String plantName;
  final List<String> plants;
  final ValueChanged<String> onPlantSelected;
  final VoidCallback onEditName;
  final VoidCallback onAddPlant;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
    decoration: const BoxDecoration(
      color: _greenDark,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Dashboard – $plantName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              onPressed: () => showNotificationDrawer(context),
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.spa_outlined, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: plantName,
                  isExpanded: true,
                  dropdownColor: _greenDark,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  items: [
                    ...plants.map(
                      (name) => DropdownMenuItem(
                        value: name,
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: '__add__',
                      child: Text(
                        '+ Adicionar planta',
                        style: TextStyle(color: Color(0xFF7FF2B6)),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == '__add__') {
                      onAddPlant();
                    } else if (value != null) {
                      onPlantSelected(value);
                    }
                  },
                ),
              ),
            ),
            IconButton(
              onPressed: onEditName,
              tooltip: 'Editar nome',
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
            ),
          ],
        ),
      ],
    ),
  );
}

class IrrigationControlMockScreen extends StatefulWidget {
  const IrrigationControlMockScreen({
    required this.plantName,
    required this.plants,
    required this.initialMode,
    required this.initialValve2Mode,
    required this.initialFrequency,
    required this.initialScheduleTimes,
    required this.onPlantSelected,
    required this.onEditName,
    required this.onAddPlant,
    required this.onModeChanged,
    required this.onValve2Changed,
    required this.onFrequencyChanged,
    required this.onSave,
    super.key,
  });
  final String plantName;
  final List<String> plants;
  final String initialMode;
  final String initialValve2Mode;
  final String initialFrequency;
  final List<ScheduleTimeInput> initialScheduleTimes;
  final ValueChanged<String> onPlantSelected;
  final VoidCallback onEditName;
  final VoidCallback onAddPlant;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<String> onValve2Changed;
  final ValueChanged<String> onFrequencyChanged;
  final ValueChanged<IrrigationControlConfiguration> onSave;

  @override
  State<IrrigationControlMockScreen> createState() =>
      _IrrigationControlMockScreenState();
}

class IrrigationControlConfiguration {
  const IrrigationControlConfiguration({
    required this.mode,
    required this.valve2Mode,
    required this.frequencyDays,
    required this.finishMode,
    required this.durationSeconds,
    required this.soilTrigger,
    required this.soilHumidityTarget,
    required this.scheduleTimes,
  });

  final String mode;
  final String valve2Mode;
  final int frequencyDays;
  final String finishMode;
  final int durationSeconds;
  final double soilTrigger;
  final double soilHumidityTarget;
  final List<ScheduleTimeInput> scheduleTimes;
}

class _ManualHomeControls extends StatelessWidget {
  const _ManualHomeControls({
    required this.valve2Mode,
    required this.onValve2Changed,
  });
  final String valve2Mode;
  final ValueChanged<String> onValve2Changed;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.water_drop_outlined),
        label: const Text('Nebulização', overflow: TextOverflow.ellipsis),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.water_drop_outlined),
        label: Text(valve2Mode, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}

class _ManualValve2ControlCard extends StatelessWidget {
  const _ManualValve2ControlCard({
    required this.valve2Mode,
    required this.onValve2Changed,
  });
  final String valve2Mode;
  final ValueChanged<String> onValve2Changed;

  @override
  Widget build(BuildContext context) => _WizardCard(
    icon: Icons.alt_route_rounded,
    title: 'Válvulas',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Escolha o modo que está utilizando atualmente na válvula 2',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: valve2Mode,
          decoration: const InputDecoration(
            labelText: 'Válvula 2',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'Gotejamento', child: Text('Gotejamento')),
            DropdownMenuItem(
              value: 'Microaspersão',
              child: Text('Microaspersão'),
            ),
          ],
          onChanged: (value) {
            if (value != null) onValve2Changed(value);
          },
        ),
      ],
    ),
  );
}

class _ValveVerticalSummary extends StatelessWidget {
  const _ValveVerticalSummary({required this.valve2Mode, required this.onEdit});
  final String valve2Mode;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _ValveDescription(label: 'Válvula 1', value: 'Nebulização'),
      Row(
        children: [
          Expanded(
            child: _ValveDescription(label: 'Válvula 2', value: valve2Mode),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onEdit,
            tooltip: 'Editar Válvula 2',
            icon: const Icon(Icons.edit_outlined, color: _green, size: 20),
          ),
        ],
      ),
    ],
  );
}

// Mantido como referência para uma futura tela dedicada de válvulas.
// ignore: unused_element
class _ValveControlCard extends StatelessWidget {
  const _ValveControlCard({
    required this.valve2Mode,
    required this.onValve2Changed,
  });
  final String valve2Mode;
  final ValueChanged<String> onValve2Changed;

  @override
  Widget build(BuildContext context) => _WizardCard(
    icon: Icons.alt_route_rounded,
    title: 'Válvulas',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ValveDescription(label: 'Válvula 1', value: 'Nebulização'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: valve2Mode,
          decoration: const InputDecoration(
            labelText: 'Válvula 2',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'Gotejamento', child: Text('Gotejamento')),
            DropdownMenuItem(
              value: 'Microaspersão',
              child: Text('Microaspersão'),
            ),
          ],
          onChanged: (value) {
            if (value != null) onValve2Changed(value);
          },
        ),
      ],
    ),
  );
}

class _IrrigationControlMockScreenState
    extends State<IrrigationControlMockScreen>
    with SingleTickerProviderStateMixin {
  late String mode;
  String target = 'Duração';
  int frequencyDays = 1;
  double duration = 30;
  double moisture = 35;
  double targetMoisture = 50;
  bool manualAutomaticStop = true;
  double manualDuration = 30;
  double manualSafetyTime = 120;
  String valve2Mode = 'Gotejamento';
  final times = <String>['08:00', '18:00'];
  final timeDurations = <double>[30, 30];
  final timeValves = <String>['valve_2', 'valve_2'];
  bool isEditingIntelligent = false;
  bool hasUnsavedChanges = false;
  late final AnimationController savePulseController;

  String _validValve(String value) =>
      value == 'valve_1' || value == 'valve_2' ? value : 'valve_2';

  @override
  void initState() {
    super.initState();
    savePulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    mode = widget.initialMode;
    valve2Mode = widget.initialValve2Mode;
    frequencyDays = int.tryParse(widget.initialFrequency) ?? 1;
    _loadScheduleTimes(widget.initialScheduleTimes);
  }

  void _loadScheduleTimes(List<ScheduleTimeInput> configured) {
    if (configured.isEmpty) return;
    times
      ..clear()
      ..addAll(configured.map((item) => item.timeOfDay));
    timeDurations
      ..clear()
      ..addAll(
        configured.map((item) => (item.durationSeconds ?? 30).toDouble()),
      );
    timeValves
      ..clear()
      ..addAll(configured.map((item) => _validValve(item.valve)));
  }

  void changeMode(String value) {
    setState(() => mode = value);
    markChanged();
  }

  void markChanged() {
    if (hasUnsavedChanges) return;
    setState(() => hasUnsavedChanges = true);
    savePulseController.repeat(reverse: true);
  }

  void saveChanges() {
    widget.onModeChanged(mode);
    widget.onValve2Changed(valve2Mode);
    widget.onFrequencyChanged(frequencyDays.toString());
    setState(() => hasUnsavedChanges = false);
    savePulseController.stop();
    savePulseController.reset();
    widget.onSave(
      IrrigationControlConfiguration(
        mode: mode,
        valve2Mode: valve2Mode,
        frequencyDays: frequencyDays,
        finishMode: target,
        durationSeconds: duration.round(),
        soilTrigger: moisture,
        soilHumidityTarget: targetMoisture,
        scheduleTimes: [
          for (var index = 0; index < times.length; index++)
            ScheduleTimeInput(
              timeOfDay: times[index],
              durationSeconds: timeDurations[index].round(),
              valve: timeValves[index],
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    savePulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant IrrigationControlMockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMode != widget.initialMode ||
        oldWidget.initialValve2Mode != widget.initialValve2Mode ||
        oldWidget.initialFrequency != widget.initialFrequency ||
        oldWidget.initialScheduleTimes != widget.initialScheduleTimes) {
      mode = widget.initialMode;
      valve2Mode = widget.initialValve2Mode;
      frequencyDays = int.tryParse(widget.initialFrequency) ?? 1;
      _loadScheduleTimes(widget.initialScheduleTimes);
      hasUnsavedChanges = false;
      savePulseController.stop();
      savePulseController.reset();
      isEditingIntelligent = false;
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ControlPlantHeader(
          plantName: widget.plantName,
          plants: widget.plants,
          onPlantSelected: widget.onPlantSelected,
          onEditName: widget.onEditName,
          onAddPlant: widget.onAddPlant,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Controle de irrigação',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: _greenDark, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Escolha o modo de funcionamento e ajuste seus parâmetros.',
                style: TextStyle(color: Colors.black54, fontSize: 15),
              ),
              const SizedBox(height: 22),
              _WizardCard(
                icon: Icons.water_drop_outlined,
                title: 'Modo de irrigação',
                child: DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Manual', child: Text('Manual')),
                    DropdownMenuItem(
                      value: 'Programado',
                      child: Text('Programado'),
                    ),
                    DropdownMenuItem(
                      value: 'Inteligente',
                      child: Text('Inteligente'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) changeMode(value);
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (mode == 'Manual') _buildManualControlV2(),
              if (mode == 'Programado') _buildProgrammedControlV3(),
              if (mode == 'Inteligente') _buildIntelligentControlV4(),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: AnimatedBuilder(
                  animation: savePulseController,
                  builder: (context, child) => Transform.scale(
                    scale: hasUnsavedChanges
                        ? 1 + savePulseController.value * .035
                        : 1,
                    child: child,
                  ),
                  child: FilledButton.icon(
                    onPressed: hasUnsavedChanges ? saveChanges : null,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar alterações'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildManualControlV2() => _WizardCard(
    icon: Icons.touch_app_outlined,
    title: 'Controle manual',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ManualValve2ControlCard(
          valve2Mode: valve2Mode,
          onValve2Changed: (value) {
            setState(() => valve2Mode = value);
            markChanged();
          },
        ),
        const SizedBox(height: 12),
        _buildManualSafetyControl(),
        const SizedBox(height: 12),
        const Text(
          'O modo manual não possui programação automática.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.water_drop),
              label: const Text('Nebulização', overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.water_drop),
              label: Text(valve2Mode, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Os comandos serão habilitados quando o ESP32 estiver conectado.',
          style: TextStyle(fontSize: 12, color: Colors.black45),
        ),
      ],
    ),
  );

  Widget _buildManualSafetyControl() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Segurança da irrigação manual',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Desativação automática'),
        subtitle: Text(
          manualAutomaticStop
              ? 'Fecha a válvula ao fim do tempo escolhido.'
              : 'Ativa o tempo máximo de segurança do ESP32.',
        ),
        value: manualAutomaticStop,
        onChanged: (value) => setState(() => manualAutomaticStop = value),
      ),
      _NumericDurationField(
        value: manualAutomaticStop ? manualDuration : manualSafetyTime,
        onChanged: (value) => setState(() {
          if (manualAutomaticStop) {
            manualDuration = value;
          } else {
            manualSafetyTime = value;
          }
        }),
      ),
      if (!manualAutomaticStop)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Ao atingir o limite, a bomba será desligada e a trava de segurança será notificada.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ),
    ],
  );

  Widget _buildFrequencySelector() => TextFormField(
    keyboardType: TextInputType.number,
    initialValue: frequencyDays.toString(),
    decoration: const InputDecoration(
      labelText: 'Intervalo entre regas',
      prefixText: 'A cada ',
      suffixText: ' dia(s)',
      border: OutlineInputBorder(),
    ),
    onChanged: (value) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        setState(() => frequencyDays = parsed.clamp(1, 30));
        markChanged();
      }
    },
  );

  // Versão anterior mantida como referência visual.
  // ignore: unused_element
  Widget _buildManualControl() => _WizardCard(
    icon: Icons.touch_app_outlined,
    title: 'Controle manual',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ManualValve2ControlCard(
          valve2Mode: valve2Mode,
          onValve2Changed: (value) {
            setState(() => valve2Mode = value);
            widget.onValve2Changed(value);
          },
        ),
        const SizedBox(height: 12),
        const Text(
          'O modo manual não possui programação automática.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.water_drop),
                label: const Text('Válvula 1'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.water_drop),
                label: const Text('Válvula 2'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Os comandos serão habilitados quando o ESP32 estiver conectado.',
          style: TextStyle(fontSize: 12, color: Colors.black45),
        ),
      ],
    ),
  );

  Widget _buildControlTimeRow(int index) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text('Horário ${index + 1}'),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => _selectControlTime(index),
            icon: const Icon(Icons.access_time, size: 18),
            label: Text(times[index]),
          ),
          if (times.length > 1)
            IconButton(
              onPressed: () {
                setState(() {
                  times.removeAt(index);
                  timeDurations.removeAt(index);
                  timeValves.removeAt(index);
                });
                markChanged();
              },
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      if (target == 'Duração')
        _NumericDurationField(
          value: timeDurations[index],
          onChanged: (value) {
            setState(() => timeDurations[index] = value);
            markChanged();
          },
        ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _validValve(timeValves[index]),
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Válvula utilizada nesta rega',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(
            value: 'valve_1',
            child: Text(
              'Válvula 1 — Nebulização',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DropdownMenuItem(
            value: 'valve_2',
            child: Text(
              'Válvula 2 — $valve2Mode',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => timeValves[index] = value);
          markChanged();
        },
      ),
    ],
  );

  Widget _buildProgrammedControlV3() => _WizardCard(
    icon: Icons.schedule_rounded,
    title: 'Programação de regas',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ValveVerticalSummary(
          valve2Mode: valve2Mode,
          onEdit: _editIntelligentValve2,
        ),
        const SizedBox(height: 14),
        _buildFrequencySelector(),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text(
              'Regas por dia',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            IconButton(
              onPressed: times.length <= 1
                  ? null
                  : () {
                      setState(() {
                        times.removeLast();
                        timeDurations.removeLast();
                        timeValves.removeLast();
                      });
                      markChanged();
                    },
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              '${times.length}',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
              ),
            ),
            IconButton(
              onPressed: times.length >= 6
                  ? null
                  : () {
                      setState(() {
                        times.add('12:00');
                        timeDurations.add(30);
                        timeValves.add('valve_2');
                      });
                      markChanged();
                    },
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        ...List.generate(times.length, (index) => _buildControlTimeRow(index)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: target,
          decoration: const InputDecoration(
            labelText: 'Finalizar cada rega por',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'Duração', child: Text('Duração')),
            DropdownMenuItem(value: 'Umidade', child: Text('Umidade do solo')),
          ],
          onChanged: (value) {
            setState(() => target = value ?? target);
            markChanged();
          },
        ),
        const SizedBox(height: 12),
        if (target == 'Umidade') ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Iniciar irrigação abaixo de'),
              Text(
                '${moisture.round()}%',
                style: const TextStyle(
                  color: _green,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            value: moisture,
            min: 10,
            max: 80,
            divisions: 70,
            activeColor: _green,
            onChanged: (value) {
              setState(() => moisture = value);
              markChanged();
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Finalizar ao atingir'),
              Text(
                '${targetMoisture.round()}%',
                style: const TextStyle(
                  color: _green,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            value: targetMoisture,
            min: 20,
            max: 95,
            divisions: 75,
            activeColor: _green,
            onChanged: (value) {
              setState(() => targetMoisture = value);
              markChanged();
            },
          ),
        ],
      ],
    ),
  );

  // Versão anterior mantida como referência visual.
  // ignore: unused_element
  Widget _buildProgrammedControlV2() => _WizardCard(
    icon: Icons.schedule_rounded,
    title: 'Programação de regas',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${times.length} regas por dia',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        ...List.generate(
          times.length,
          (index) => Row(
            children: [
              Text('Rega ${index + 1}'),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.access_time, size: 18),
                label: Text(times[index]),
              ),
            ],
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: target,
          decoration: const InputDecoration(
            labelText: 'Finalizar cada rega por',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'Duração', child: Text('Duração')),
            DropdownMenuItem(value: 'Umidade', child: Text('Umidade do solo')),
          ],
          onChanged: (value) => setState(() => target = value ?? target),
        ),
        const SizedBox(height: 12),
        if (target == 'Duração')
          _NumericDurationField(
            value: duration,
            onChanged: (value) => setState(() => duration = value),
          ),
        if (target == 'Umidade')
          Slider(
            value: moisture,
            min: 10,
            max: 80,
            divisions: 70,
            activeColor: _green,
            onChanged: (value) => setState(() => moisture = value),
          ),
      ],
    ),
  );

  // Versão anterior mantida como referência visual.
  // ignore: unused_element
  Widget _buildProgrammedControl() => _WizardCard(
    icon: Icons.schedule_rounded,
    title: 'Programação de regas',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${times.length} regas por dia',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...List.generate(
          times.length,
          (index) => Row(
            children: [
              Text('Rega ${index + 1}'),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.access_time, size: 18),
                label: Text(times[index]),
              ),
              IconButton(
                onPressed: times.length > 1
                    ? () => setState(() => times.removeAt(index))
                    : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: times.length >= 6
              ? null
              : () => setState(() => times.add('12:00')),
          icon: const Icon(Icons.add),
          label: const Text('Adicionar horário'),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: target,
          decoration: const InputDecoration(
            labelText: 'Finalizar cada rega por',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'Duração', child: Text('Duração')),
            DropdownMenuItem(value: 'Umidade', child: Text('Umidade do solo')),
          ],
          onChanged: (value) => setState(() => target = value ?? target),
        ),
        const SizedBox(height: 12),
        if (target == 'Duração') ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Duração'),
              Text(
                '${duration.round()} segundos',
                style: const TextStyle(
                  color: _green,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            value: duration,
            min: 5,
            max: 300,
            divisions: 59,
            activeColor: _green,
            onChanged: (value) => setState(() => duration = value),
          ),
        ],
        if (target == 'Umidade') ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Gatilho'),
              Text(
                'Abaixo de ${moisture.round()}%',
                style: const TextStyle(
                  color: _green,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            value: moisture,
            min: 10,
            max: 80,
            divisions: 70,
            activeColor: _green,
            onChanged: (value) => setState(() => moisture = value),
          ),
        ],
      ],
    ),
  );

  Widget _buildIntelligentControlV4() => _WizardCard(
    icon: Icons.auto_awesome,
    title: 'Configuração sugerida pela IA',
    headerAction: IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      onPressed: () =>
          setState(() => isEditingIntelligent = !isEditingIntelligent),
      tooltip: isEditingIntelligent
          ? 'Bloquear configuração'
          : 'Editar configuração',
      icon: Icon(
        isEditingIntelligent ? Icons.lock_open_rounded : Icons.edit_outlined,
        color: _green,
        size: 22,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Configuração protegida. Toque no lápis para editar.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sugestão atual: gotejamento por 30 segundos abaixo de 35% de umidade.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        const _ValveDescription(label: 'Válvula 1', value: 'Nebulização'),
        Row(
          children: [
            Expanded(
              child: _ValveDescription(label: 'Válvula 2', value: valve2Mode),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: isEditingIntelligent ? _editIntelligentValve2 : null,
              tooltip: 'Editar Válvula 2',
              icon: const Icon(Icons.edit_outlined, color: _green, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 14),
        IgnorePointer(
          ignoring: !isEditingIntelligent,
          child: Opacity(
            opacity: isEditingIntelligent ? 1 : .58,
            child: _buildIntelligentFieldsCleanV2(),
          ),
        ),
      ],
    ),
  );

  // Versão anterior mantida como referência visual.
  // ignore: unused_element
  Widget _buildIntelligentControlV3() => _WizardCard(
    icon: Icons.auto_awesome,
    title: 'Configuração sugerida pela IA',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            onPressed: () =>
                setState(() => isEditingIntelligent = !isEditingIntelligent),
            tooltip: isEditingIntelligent
                ? 'Bloquear configuração'
                : 'Editar configuração',
            icon: Icon(
              isEditingIntelligent
                  ? Icons.lock_open_rounded
                  : Icons.edit_outlined,
              color: _green,
              size: 22,
            ),
          ),
        ),
        const Text(
          'Configuração protegida. Toque no lápis para editar.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sugestão atual: gotejamento por 30 segundos abaixo de 35% de umidade.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: _ValveDescription(
                label: 'Válvula 1',
                value: 'Nebulização',
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _ValveDescription(
                      label: 'Válvula 2',
                      value: valve2Mode,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _editIntelligentValve2,
                    tooltip: 'Editar Válvula 2',
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: _green,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        IgnorePointer(
          ignoring: !isEditingIntelligent,
          child: Opacity(
            opacity: isEditingIntelligent ? 1 : .58,
            child: _buildIntelligentFieldsClean(),
          ),
        ),
      ],
    ),
  );

  Widget _buildIntelligentFieldsCleanV2() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildFrequencySelector(),
      const SizedBox(height: 12),
      Row(
        children: [
          const Text(
            'Regas por dia',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          IconButton(
            onPressed: times.length <= 1
                ? null
                : () => setState(() {
                    times.removeLast();
                    timeDurations.removeLast();
                    timeValves.removeLast();
                  }),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            '${times.length}',
            style: const TextStyle(color: _green, fontWeight: FontWeight.w800),
          ),
          IconButton(
            onPressed: times.length >= 6
                ? null
                : () => setState(() {
                    times.add('12:00');
                    timeDurations.add(30);
                    timeValves.add('valve_2');
                  }),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      ...List.generate(times.length, (index) => _buildControlTimeRow(index)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: target,
        decoration: const InputDecoration(
          labelText: 'Finalizar irrigação por',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'Duração', child: Text('Duração')),
          DropdownMenuItem(value: 'Umidade', child: Text('Umidade do solo')),
        ],
        onChanged: (value) {
          setState(() => target = value ?? target);
          markChanged();
        },
      ),
      const SizedBox(height: 12),
      if (target == 'Umidade') ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Iniciar irrigação abaixo de'),
            Text(
              '${moisture.round()}%',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          value: moisture,
          min: 10,
          max: 80,
          divisions: 70,
          activeColor: _green,
          onChanged: (value) {
            setState(() => moisture = value);
            markChanged();
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Finalizar ao atingir'),
            Text(
              '${targetMoisture.round()}%',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          value: targetMoisture,
          min: 20,
          max: 95,
          divisions: 75,
          activeColor: _green,
          onChanged: (value) {
            setState(() => targetMoisture = value);
            markChanged();
          },
        ),
      ],
    ],
  );

  // Versão anterior mantida como referência visual.
  // ignore: unused_element
  Widget _buildIntelligentFieldsClean() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Text(
            'Regas por dia',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          IconButton(
            onPressed: times.length <= 1
                ? null
                : () => setState(() => times.removeLast()),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            '${times.length}',
            style: const TextStyle(color: _green, fontWeight: FontWeight.w800),
          ),
          IconButton(
            onPressed: times.length >= 6
                ? null
                : () => setState(() => times.add('12:00')),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      ...List.generate(
        times.length,
        (index) => Row(
          children: [
            Text('Horário ${index + 1}'),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _selectControlTime(index),
              icon: const Icon(Icons.access_time, size: 18),
              label: Text(times[index]),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: target,
        decoration: const InputDecoration(
          labelText: 'Finalizar irrigação por',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'Duração', child: Text('Duração')),
          DropdownMenuItem(value: 'Umidade', child: Text('Umidade do solo')),
        ],
        onChanged: (value) => setState(() => target = value ?? target),
      ),
      const SizedBox(height: 12),
      if (target == 'Duração') ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Duração'),
            Text(
              '${duration.round()} segundos',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          value: duration,
          min: 5,
          max: 300,
          divisions: 59,
          activeColor: _green,
          onChanged: (value) => setState(() => duration = value),
        ),
      ],
      if (target == 'Umidade') ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Gatilho'),
            Text(
              'Abaixo de ${moisture.round()}%',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          value: moisture,
          min: 10,
          max: 80,
          divisions: 70,
          activeColor: _green,
          onChanged: (value) => setState(() => moisture = value),
        ),
      ],
    ],
  );

  // Versão anterior mantida como referência visual.
  // ignore: unused_element
  Widget _buildIntelligentControlV2() => _WizardCard(
    icon: Icons.auto_awesome,
    title: 'Configuração sugerida pela IA',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Configuração protegida. Toque no lápis para editar.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            IconButton(
              onPressed: () =>
                  setState(() => isEditingIntelligent = !isEditingIntelligent),
              tooltip: isEditingIntelligent
                  ? 'Bloquear configuração'
                  : 'Editar configuração',
              icon: Icon(
                isEditingIntelligent
                    ? Icons.lock_open_rounded
                    : Icons.edit_outlined,
                color: _green,
              ),
            ),
          ],
        ),
        const Text(
          'Sugestão atual: gotejamento por 30 segundos abaixo de 35% de umidade.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: _ValveDescription(
                label: 'Válvula 1',
                value: 'Nebulização',
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _ValveDescription(
                      label: 'Válvula 2',
                      value: valve2Mode,
                    ),
                  ),
                  IconButton(
                    onPressed: _editIntelligentValve2,
                    tooltip: 'Editar Válvula 2',
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: _green,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        IgnorePointer(
          ignoring: !isEditingIntelligent,
          child: Opacity(
            opacity: isEditingIntelligent ? 1 : .58,
            child: _buildIntelligentFields(),
          ),
        ),
      ],
    ),
  );

  Future<void> _editIntelligentValve2() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Escolha a Válvula 2'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Gotejamento'),
            child: const Text('Gotejamento'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Microaspersão'),
            child: const Text('Microaspersão'),
          ),
        ],
      ),
    );
    if (selected == null) return;
    setState(() => valve2Mode = selected);
    markChanged();
  }

  Widget _buildIntelligentFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _ValveDescription(label: 'Válvula 1', value: 'Nebulização'),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: valve2Mode,
        decoration: const InputDecoration(
          labelText: 'Válvula 2',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'Gotejamento', child: Text('Gotejamento')),
          DropdownMenuItem(
            value: 'Microaspersão',
            child: Text('Microaspersão'),
          ),
        ],
        onChanged: (value) => setState(() => valve2Mode = value ?? valve2Mode),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          const Text(
            'Regas por dia',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          IconButton(
            onPressed: times.length <= 1
                ? null
                : () => setState(() => times.removeLast()),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            '${times.length}',
            style: const TextStyle(color: _green, fontWeight: FontWeight.w800),
          ),
          IconButton(
            onPressed: times.length >= 6
                ? null
                : () => setState(() => times.add('12:00')),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      ...List.generate(
        times.length,
        (index) => Row(
          children: [
            Text('Horário ${index + 1}'),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _selectControlTime(index),
              icon: const Icon(Icons.access_time, size: 18),
              label: Text(times[index]),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: target,
        decoration: const InputDecoration(
          labelText: 'Finalizar irrigação por',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'Duração', child: Text('Duração')),
          DropdownMenuItem(value: 'Umidade', child: Text('Umidade do solo')),
        ],
        onChanged: (value) => setState(() => target = value ?? target),
      ),
      const SizedBox(height: 12),
      if (target == 'Duração') ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Duração'),
            Text(
              '${duration.round()} segundos',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          value: duration,
          min: 5,
          max: 300,
          divisions: 59,
          activeColor: _green,
          onChanged: (value) => setState(() => duration = value),
        ),
      ],
      if (target == 'Umidade') ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Gatilho'),
            Text(
              'Abaixo de ${moisture.round()}%',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          value: moisture,
          min: 10,
          max: 80,
          divisions: 70,
          activeColor: _green,
          onChanged: (value) => setState(() => moisture = value),
        ),
      ],
    ],
  );

  Future<void> _selectControlTime(int index) async {
    final parts = times[index].split(':');
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (selected == null) return;
    setState(
      () => times[index] =
          '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}',
    );
    markChanged();
  }

  // Mantido como referência da primeira versão visual.
  // ignore: unused_element
  Widget _buildIntelligentControl() => _WizardCard(
    icon: Icons.auto_awesome,
    title: 'Configuração sugerida pela IA',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Modo inteligente usa o modo de irrigação recomendado pela IA.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sugestão atual: gotejamento por 30 segundos abaixo de 35% de umidade.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: target,
          decoration: const InputDecoration(
            labelText: 'A irrigação termina por',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'Duração', child: Text('Duração')),
            DropdownMenuItem(value: 'Umidade', child: Text('Umidade do solo')),
          ],
          onChanged: (value) => setState(() => target = value ?? target),
        ),
        const SizedBox(height: 12),
        if (target == 'Duração')
          Slider(
            value: duration,
            min: 5,
            max: 300,
            divisions: 59,
            activeColor: _green,
            onChanged: (value) => setState(() => duration = value),
          ),
        if (target == 'Umidade')
          Slider(
            value: moisture,
            min: 10,
            max: 80,
            divisions: 70,
            activeColor: _green,
            onChanged: (value) => setState(() => moisture = value),
          ),
      ],
    ),
  );
}

class IrrigationMockScreen extends StatelessWidget {
  const IrrigationMockScreen({super.key});
  @override
  Widget build(BuildContext context) => const _SimpleMockPage(
    title: 'Config. de irrigação',
    icon: Icons.water_drop_outlined,
    message: 'Configure os modos manual, programado e automático.',
  );
}

class PlantInfoMockScreen extends StatefulWidget {
  const PlantInfoMockScreen({
    required this.plantName,
    required this.irrigationMode,
    this.plantId,
    this.notificationStore,
    this.onSignOut,
    required this.onEdit,
    required this.onRename,
    required this.onDelete,
    required this.onResetEsp,
    super.key,
  });
  final String plantName;
  final String irrigationMode;
  final String? plantId;
  final SupabaseNotificationStore? notificationStore;
  final Future<void> Function()? onSignOut;
  final VoidCallback onEdit;
  final ValueChanged<String> onRename;
  final Future<void> Function() onDelete;
  final Future<void> Function() onResetEsp;

  @override
  State<PlantInfoMockScreen> createState() => _PlantInfoMockScreenState();
}

class _PlantInfoMockScreenState extends State<PlantInfoMockScreen> {
  static const _drySoilNotificationKey = 'Solo seco — hora de regar';
  static const _dryAirNotificationKey = 'Sugestão de nebulização';
  final notificationSettings = <String, bool>{
    '\u0049rriga\u00e7\u00e3o realizada': true,
    'Luminosidade excedente': true,
    'Estresse t\u00e9rmico': true,
    'Solo seco \u2014 hora de regar': true,
    'Sugest\u00e3o de nebuliza\u00e7\u00e3o': false,
    'Confirma\u00e7\u00e3o de fim de rega manual': true,
    'Trava de seguran\u00e7a (watchdog)': true,
  };
  double lightLimit = 80;
  double thermalLimit = 30;
  double drySoilLimit = 35;
  double dryAirLimit = 35;

  bool get isManualMode => widget.irrigationMode == 'Manual';

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    if (widget.plantId == null || widget.notificationStore == null) return;
    final preferences = await widget.notificationStore!.load(widget.plantId!);
    if (!mounted) return;
    setState(() {
      notificationSettings['IrrigaÃ§Ã£o realizada'] =
          preferences.irrigationCompleted;
      notificationSettings['Luminosidade excedente'] =
          preferences.excessiveLight;
      notificationSettings['Estresse tÃ©rmico'] = preferences.thermalStress;
      notificationSettings['Solo seco â€” hora de regar'] = preferences.drySoil;
      notificationSettings['SugestÃ£o de nebulizaÃ§Ã£o'] = preferences.dryAir;
      notificationSettings['ConfirmaÃ§Ã£o de fim de rega manual'] =
          preferences.manualCompleted;
      notificationSettings['Trava de seguranÃ§a (watchdog)'] =
          preferences.safetyWatchdog;
      lightLimit = preferences.excessiveLightLimit;
      thermalLimit = preferences.thermalMax;
      drySoilLimit = preferences.drySoilLimit;
      dryAirLimit = preferences.dryAirLimit;
      // Remove entradas antigas geradas por uma versão com codificação
      // incorreta. As chaves originais da lista permanecem intactas.
      notificationSettings.removeWhere((key, _) => key.contains('\u00c3'));
      final keys = notificationSettings.keys.toList();
      notificationSettings[keys[0]] = preferences.irrigationCompleted;
      notificationSettings[keys[1]] = preferences.excessiveLight;
      notificationSettings[keys[2]] = preferences.thermalStress;
      notificationSettings[keys[3]] = preferences.drySoil;
      notificationSettings[keys[4]] = preferences.dryAir;
      notificationSettings[keys[5]] = preferences.manualCompleted;
      notificationSettings[keys[6]] = preferences.safetyWatchdog;
      if (!isManualMode) {
        notificationSettings[_drySoilNotificationKey] = false;
        notificationSettings[_dryAirNotificationKey] = false;
      }
    });
  }

  // ignore: unused_element
  Future<void> _saveNotificationPreferences() async {
    if (widget.plantId == null || widget.notificationStore == null) return;
    await widget.notificationStore!.save(
      widget.plantId!,
      PlantNotificationPreferences(
        irrigationCompleted:
            notificationSettings['IrrigaÃ§Ã£o realizada'] ?? true,
        excessiveLight: notificationSettings['Luminosidade excedente'] ?? true,
        excessiveLightLimit: lightLimit,
        thermalStress: notificationSettings['Estresse tÃ©rmico'] ?? true,
        thermalMax: thermalLimit,
        drySoil:
            isManualMode &&
            (notificationSettings[_drySoilNotificationKey] ?? true),
        drySoilLimit: drySoilLimit,
        dryAir:
            isManualMode &&
            (notificationSettings[_dryAirNotificationKey] ?? false),
        dryAirLimit: dryAirLimit,
        manualCompleted:
            notificationSettings['ConfirmaÃ§Ã£o de fim de rega manual'] ?? true,
        safetyWatchdog:
            notificationSettings['Trava de seguranÃ§a (watchdog)'] ?? true,
      ),
    );
  }

  Future<void> _persistNotificationSettings() async {
    if (widget.plantId == null || widget.notificationStore == null) return;
    final values = notificationSettings.values.toList();
    await widget.notificationStore!.save(
      widget.plantId!,
      PlantNotificationPreferences(
        irrigationCompleted: values.elementAt(0),
        excessiveLight: values.elementAt(1),
        excessiveLightLimit: lightLimit,
        thermalStress: values.elementAt(2),
        thermalMax: thermalLimit,
        drySoil: isManualMode && values.elementAt(3),
        drySoilLimit: drySoilLimit,
        dryAir: isManualMode && values.elementAt(4),
        dryAirLimit: dryAirLimit,
        manualCompleted: values.elementAt(5),
        safetyWatchdog: values.elementAt(6),
      ),
    );
  }

  // Mantido para futuras edições rápidas diretamente nesta tela.
  // ignore: unused_element
  Future<void> _editPlant() async {
    final popularController = TextEditingController(text: widget.plantName);
    final scientificController = TextEditingController();
    var model = 'Manjericão';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar planta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: model,
                  decoration: const InputDecoration(
                    labelText: 'Modelo identificado pela IA',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Manjericão',
                      child: Text('Manjericão'),
                    ),
                    DropdownMenuItem(value: 'Tomate', child: Text('Tomate')),
                    DropdownMenuItem(
                      value: 'Pimenteira',
                      child: Text('Pimenteira'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => model = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: popularController,
                  decoration: const InputDecoration(
                    labelText: 'Nome popular',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: scientificController,
                  decoration: const InputDecoration(
                    labelText: 'Nome científico',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                popularController.text.trim().isEmpty
                    ? model
                    : popularController.text.trim(),
              ),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    popularController.dispose();
    scientificController.dispose();
    if (result != null && result.isNotEmpty) widget.onRename(result);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir planta?'),
        content: Text(
          'A configuração de ${widget.plantName} será removida do aplicativo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onDelete();
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Você precisará entrar novamente para acessar suas plantas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (widget.onSignOut != null) {
      await widget.onSignOut!.call();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma sessão autenticada está ativa.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Planta',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: _greenDark, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        _WizardCard(
          icon: Icons.local_florist_outlined,
          title: widget.plantName,
          child: FilledButton.icon(
            onPressed: widget.onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar planta / identificação'),
          ),
        ),
        const SizedBox(height: 14),
        _WizardCard(
          icon: Icons.memory_outlined,
          title: 'Configuração do ESP32',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wi-Fi configurado: Minha Casa 2.4G',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fluxo de troca de Wi-Fi aberto.'),
                  ),
                ),
                icon: const Icon(Icons.wifi),
                label: const Text('Trocar conexão Wi-Fi'),
              ),
              OutlinedButton.icon(
                onPressed: widget.onResetEsp,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Resetar para modo Access Point'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _WizardCard(
          icon: Icons.notifications_outlined,
          title: 'Notificações configuráveis',
          child: Column(
            children: [
              ...notificationSettings.keys.map(
                (label) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(label),
                  subtitle:
                      (label == _drySoilNotificationKey ||
                              label == _dryAirNotificationKey) &&
                          !isManualMode
                      ? const Text('Disponível somente no modo manual')
                      : null,
                  value:
                      (label == _drySoilNotificationKey ||
                          label == _dryAirNotificationKey)
                      ? isManualMode && notificationSettings[label]!
                      : notificationSettings[label]!,
                  onChanged:
                      (label == _drySoilNotificationKey ||
                              label == _dryAirNotificationKey) &&
                          !isManualMode
                      ? null
                      : (value) {
                          setState(() => notificationSettings[label] = value);
                          _persistNotificationSettings();
                        },
                ),
              ),
              if (isManualMode &&
                  notificationSettings[_drySoilNotificationKey] == true) ...[
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Alertar umidade abaixo de',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('${drySoilLimit.round()}%'),
                  ],
                ),
                Slider(
                  value: drySoilLimit,
                  min: 10,
                  max: 80,
                  divisions: 70,
                  activeColor: _green,
                  onChanged: (value) {
                    setState(() => drySoilLimit = value);
                    _persistNotificationSettings();
                  },
                ),
              ],
              if (isManualMode &&
                  notificationSettings[_dryAirNotificationKey] == true) ...[
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Alertar umidade do ar abaixo de',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('${dryAirLimit.round()}%'),
                  ],
                ),
                Slider(
                  value: dryAirLimit,
                  min: 10,
                  max: 90,
                  divisions: 80,
                  activeColor: _green,
                  onChanged: (value) {
                    setState(() => dryAirLimit = value);
                    _persistNotificationSettings();
                  },
                ),
              ],
              if (notificationSettings['Estresse t\u00e9rmico'] == true) ...[
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Limite de temperatura',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('${thermalLimit.round()} °C'),
                  ],
                ),
                Slider(
                  value: thermalLimit,
                  min: 20,
                  max: 45,
                  divisions: 25,
                  activeColor: _green,
                  onChanged: (value) {
                    setState(() => thermalLimit = value);
                    _persistNotificationSettings();
                  },
                ),
              ],
              if (notificationSettings['Luminosidade excedente'] == true) ...[
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Limite máximo de luminosidade',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('${lightLimit.round()}%'),
                  ],
                ),
                Slider(
                  value: lightLimit,
                  min: 50,
                  max: 100,
                  divisions: 50,
                  activeColor: _green,
                  onChanged: (value) {
                    setState(() => lightLimit = value);
                    _persistNotificationSettings();
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _WizardCard(
          icon: Icons.info_outline,
          title: 'Alertas automáticos do sistema',
          child: const Text(
            'Reservatório baixo, corte de emergência, status de conexão e anomalias dos sensores são avisos automáticos e não podem ser desativados aqui.',
            style: TextStyle(color: Colors.black54, height: 1.4),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _confirmDelete,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Excluir planta'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _confirmSignOut,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.black54),
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
          ),
        ),
      ],
    ),
  );
}

class HistoryMockScreen extends StatelessWidget {
  HistoryMockScreen({
    required this.plantName,
    required this.plants,
    this.plantId,
    this.historyStore,
    required this.onPlantSelected,
    required this.onAddPlant,
    super.key,
  });
  final String plantName;
  final List<String> plants;
  final String? plantId;
  final SupabaseHistoryStore? historyStore;
  final ValueChanged<String> onPlantSelected;
  final VoidCallback onAddPlant;
  final selectedPeriod = ValueNotifier<String>('7 dias');

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
          decoration: const BoxDecoration(
            color: _greenDark,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Histórico e sensores',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: 220,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: plantName,
                    isExpanded: true,
                    dropdownColor: _greenDark,
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    items: [
                      ...plants.map(
                        (name) =>
                            DropdownMenuItem(value: name, child: Text(name)),
                      ),
                      const DropdownMenuItem(
                        value: '__add__',
                        child: Text('+ Adicionar planta'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == '__add__') {
                        onAddPlant();
                      } else if (value != null) {
                        onPlantSelected(value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            children: [
              _buildPeriodSelector(),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: selectedPeriod,
                builder: (context, period, _) => Column(
                  children: [
                    _buildSensorChart(period),
                    const SizedBox(height: 12),
                    _buildIrrigationEvents(period),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildPeriodSelector() => ValueListenableBuilder<String>(
    valueListenable: selectedPeriod,
    builder: (context, period, _) => Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          _periodButton('24 h', period),
          _periodButton('7 dias', period),
          _periodButton('30 dias', period),
        ],
      ),
    ),
  );

  Widget _periodButton(String label, String selectedPeriod) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => this.selectedPeriod.value = label,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selectedPeriod == label
              ? const Color(0xFF0B9D68)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selectedPeriod == label ? Colors.white : Colors.black87,
            fontWeight: selectedPeriod == label
                ? FontWeight.w800
                : FontWeight.w400,
          ),
        ),
      ),
    ),
  );

  Widget _buildSensorChart([String period = '7 dias']) {
    if (historyStore == null || plantId == null) {
      return _buildMockSensorChart();
    }
    return FutureBuilder<List<SensorReadingRecord>>(
      future: historyStore!.listReadings(
        plantId: plantId!,
        from: DateTime.now().subtract(Duration(days: _periodDays(period))),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _historyLoadingCard('Carregando leituras...');
        }
        if (snapshot.hasError) {
          return _historyLoadingCard('Não foi possível carregar as leituras.');
        }
        final readings = snapshot.data ?? const <SensorReadingRecord>[];
        if (readings.isEmpty) {
          return _historyLoadingCard(
            'Nenhuma leitura real foi enviada pelo ESP32 ainda.',
          );
        }
        final latest = readings.last;
        return _historyDataCard(
          title: '${readings.length} leituras reais no período de $period',
          children: [
            _historyMetric('Solo', latest.soilMoisture, '%'),
            _historyMetric('Temperatura', latest.temperature, '°C'),
            _historyMetric('Umidade do ar', latest.airHumidity, '%'),
            _historyMetric('Luz', latest.illuminance, ' lux'),
          ],
        );
      },
    );
  }

  Widget _buildMockSensorChart() => Container(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 6)],
    ),
    child: Column(
      children: [
        SizedBox(
          height: 190,
          width: double.infinity,
          child: CustomPaint(painter: _HistoryChartPainter()),
        ),
        Wrap(
          spacing: 18,
          runSpacing: 6,
          children: const [
            _ChartLegend(color: Color(0xFF20B978), label: 'Umidade do solo'),
            _ChartLegend(color: Color(0xFFFFA51B), label: 'Temperatura'),
            _ChartLegend(color: Color(0xFF287DEB), label: 'Umidade do ar'),
          ],
        ),
      ],
    ),
  );

  Widget _buildIrrigationEvents([String period = '7 dias']) {
    if (historyStore == null || plantId == null) {
      return _buildMockIrrigationEvents();
    }
    return FutureBuilder<List<IrrigationEventRecord>>(
      future: historyStore!.listEvents(
        plantId: plantId!,
        from: DateTime.now().subtract(Duration(days: _periodDays(period))),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _historyLoadingCard('Carregando eventos de irrigação...');
        }
        if (snapshot.hasError) {
          return _historyLoadingCard('Não foi possível carregar os eventos.');
        }
        final events = snapshot.data ?? const <IrrigationEventRecord>[];
        if (events.isEmpty) {
          return _historyLoadingCard(
            'Nenhuma irrigação real foi registrada ainda.',
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Color(0x12000000), blurRadius: 6),
            ],
          ),
          child: Column(
            children: [
              for (final event in events)
                _HistoryEvent(
                  icon: event.status == 'completed' ? Icons.check : Icons.close,
                  color: event.status == 'completed'
                      ? const Color(0xFF149B68)
                      : Colors.redAccent,
                  time: _formatHistoryDate(event.startedAt),
                  details:
                      '${event.valve == 'valve_1' ? 'Valv1' : 'Valv2'}   •   ${event.mode}   •   ${event.durationSeconds ?? 0} s',
                  status: event.status == 'completed'
                      ? 'Concluída'
                      : (event.cancellationReason ?? 'Não concluída'),
                  failed: event.status != 'completed',
                  information: [
                    'Data e hora: ${_formatHistoryDate(event.startedAt)}',
                    'Válvula: ${event.valve == 'valve_1' ? 'Válvula 1 — Nebulização' : 'Válvula 2'}',
                    'Origem: ${event.mode}',
                    'Duração: ${event.durationSeconds ?? 0} segundos',
                    'Status: ${event.status == 'completed' ? 'Concluída' : (event.cancellationReason ?? 'Não concluída')}',
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMockIrrigationEvents() => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 6)],
    ),
    child: const Column(
      children: [
        _HistoryEvent(
          icon: Icons.check,
          color: Color(0xFF149B68),
          time: 'Hoje, 07:00',
          details: 'Valv2   •   Timer   •   45 s',
          status: 'Concluída',
          information: [
            'Data e hora: Hoje, 07:00',
            'Válvula: Válvula 2',
            'Origem: Timer',
            'Duração: 45 segundos',
            'Status: Concluída',
          ],
        ),
        _HistoryEvent(
          icon: Icons.check,
          color: Color(0xFF149B68),
          time: 'Ontem, 18:00',
          details: 'Valv2   •   Auto   •   45 s',
          status: 'Concluída',
          information: [
            'Data e hora: Ontem, 18:00',
            'Válvula: Válvula 2',
            'Origem: Automático',
            'Duração: 45 segundos',
            'Status: Concluída',
          ],
        ),
        _HistoryEvent(
          icon: Icons.close,
          color: Colors.redAccent,
          time: 'Ontem, 12:20',
          details: 'Valv1   •   Manual',
          status: 'Cancelada por falta de água',
          failed: true,
          information: [
            'Data e hora: Ontem, 12:20',
            'Válvula: Válvula 1 — Nebulização',
            'Origem: Manual',
            'Status: Cancelada por falta de água',
          ],
        ),
      ],
    ),
  );
  Widget _historyLoadingCard(String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 6)],
    ),
    child: Text(message, textAlign: TextAlign.center),
  );

  Widget _historyDataCard({
    required String title,
    required List<Widget> children,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 6)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(spacing: 18, runSpacing: 12, children: children),
      ],
    ),
  );

  Widget _historyMetric(String label, double? value, String unit) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      Text(
        value == null ? '--' : '${value.toStringAsFixed(1)}$unit',
        style: const TextStyle(
          color: _green,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  String _formatHistoryDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  int _periodDays(String period) => switch (period) {
    '24 h' => 1,
    '30 dias' => 30,
    _ => 7,
  };
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 24, height: 3, color: color),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}

class _HistoryEvent extends StatelessWidget {
  const _HistoryEvent({
    required this.icon,
    required this.color,
    required this.time,
    required this.details,
    required this.status,
    this.failed = false,
    this.information = const [],
  });
  final IconData icon;
  final Color color;
  final String time;
  final String details;
  final String status;
  final bool failed;
  final List<String> information;

  void _showDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalhes da irrigação'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: information.length,
            separatorBuilder: (_, _) => const Divider(height: 18),
            itemBuilder: (context, index) => Text(information[index]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => _showDetails(context),
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        time,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: failed
                              ? Colors.red.withValues(alpha: .08)
                              : const Color(0xFF149B68).withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          status,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: failed
                                ? Colors.red
                                : const Color(0xFF159B69),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _HistoryChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E9E7)
      ..strokeWidth = 1;
    final chart = Rect.fromLTWH(34, 12, size.width - 58, size.height - 42);
    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    for (var i = 0; i < 7; i++) {
      final x = chart.left + chart.width * i / 6;
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), gridPaint);
      _drawText(
        canvas,
        ['16/05', '17/05', '18/05', '19/05', '20/05', '21/05', '22/05'][i],
        Offset(x - 14, chart.bottom + 8),
      );
    }
    _drawSeries(canvas, chart, [
      0.55,
      0.35,
      0.38,
      0.52,
      0.40,
      0.49,
      0.38,
    ], const Color(0xFF20B978));
    _drawSeries(canvas, chart, [
      0.70,
      0.54,
      0.35,
      0.52,
      0.58,
      0.55,
      0.50,
    ], const Color(0xFFFFA51B));
    _drawSeries(canvas, chart, [
      0.78,
      0.86,
      0.72,
      0.80,
      0.77,
      0.82,
      0.76,
    ], const Color(0xFF287DEB));
  }

  void _drawSeries(
    Canvas canvas,
    Rect chart,
    List<double> values,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final point = Offset(
        chart.left + chart.width * i / (values.length - 1),
        chart.top + chart.height * values[i],
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawCircle(point, 3, Paint()..color = color);
    }
    canvas.drawPath(path, paint);
  }

  void _drawText(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 10, color: Colors.black87),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SimpleMockPage extends StatelessWidget {
  const _SimpleMockPage({
    required this.title,
    required this.icon,
    required this.message,
  });
  final String title;
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _green, size: 64),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: _greenDark, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 16),
          ),
        ],
      ),
    ),
  );
}

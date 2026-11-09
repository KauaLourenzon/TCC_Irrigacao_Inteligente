/*
 * TCC - Irrigacao Inteligente | Firmware inicial ESP32
 *
 * Nesta primeira versao os sensores sao simulados. O barramento I2C, os pinos
 * e a estrutura de comunicacao ja estao preparados para a etapa de hardware.
 *
 * Dependencia: ArduinoJson (versao 7) instalada na Arduino IDE.
 */
#include <ArduinoJson.h>
#include <ESPmDNS.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <WebServer.h>
#include <WiFi.h>
#include <Wire.h>
#include <math.h>
#include <time.h>

// ----------------------------- Pinagem -------------------------------------
constexpr uint8_t PIN_BOMBA = 5;             // D5 / GPIO5
constexpr uint8_t PIN_VALVULA_1 = 18;        // D18 / GPIO18 - nebulizacao
constexpr uint8_t PIN_VALVULA_2 = 19;        // D19 / GPIO19 - gotejamento
constexpr uint8_t PIN_SOLO = 34;              // D34 / GPIO34 - ADC
constexpr uint8_t PIN_BOIA = 27;              // D27 / GPIO27
constexpr uint8_t PIN_SDA = 21;               // D21 / GPIO21
constexpr uint8_t PIN_SCL = 22;               // D22 / GPIO22

// Modulos de rele normalmente sao acionados em nivel LOW.
constexpr uint8_t RELE_LIGADO = LOW;
constexpr uint8_t RELE_DESLIGADO = HIGH;
constexpr uint8_t BOIA_SEM_AGUA = HIGH;

constexpr bool SIMULAR_SENSORES = true;
constexpr uint8_t MAX_HORARIOS = 8;
constexpr uint32_t INTERVALO_SENSORES_MS = 10000;
constexpr uint32_t INTERVALO_NUVEM_MS = 30000;

// Deixe vazio para operar somente pela rede local. Exemplo:
// https://seu-backend.com/api
const char* CLOUD_API_BASE_URL = "";

WebServer server(80);
Preferences preferences;

enum class Modo : uint8_t { Manual, Programado, Inteligente };

struct Horario {
  bool habilitado = false;
  uint8_t hora = 8;
  uint8_t minuto = 0;
  uint16_t duracao = 30;
  uint8_t valvula = 1;
};

struct Configuracao {
  Modo modo = Modo::Inteligente;
  uint16_t intervaloDias = 1;
  Horario horarios[MAX_HORARIOS];
};

struct Leituras {
  float temperatura = 24.0f;
  float umidadeAr = 60.0f;
  float pressao = 1013.0f;
  float luminosidade = 4000.0f;
  float umidadeSolo = 55.0f;
  bool semAgua = false;
};

struct IrrigacaoAtiva {
  bool ativa = false;
  uint8_t valvula = 0;
  uint32_t inicio = 0;
  uint32_t duracao = 0;
};

Configuracao configuracao;
Leituras leituras;
IrrigacaoAtiva irrigacao;
String ultimoEvento = "boot";
uint32_t ultimaLeitura = 0;
uint32_t ultimoEnvio = 0;
int ultimoHorarioExecutado = -1;

String modoTexto(Modo modo) {
  if (modo == Modo::Manual) return "manual";
  if (modo == Modo::Programado) return "programado";
  return "inteligente";
}

Modo textoModo(const String& texto) {
  if (texto == "manual") return Modo::Manual;
  if (texto == "programado") return Modo::Programado;
  return Modo::Inteligente;
}

void responderJson(int status, JsonDocument& documento) {
  String resposta;
  serializeJson(documento, resposta);
  server.send(status, "application/json; charset=utf-8", resposta);
}

void responderErro(int status, const String& mensagem) {
  JsonDocument documento;
  documento["ok"] = false;
  documento["erro"] = mensagem;
  responderJson(status, documento);
}

void desligarAtuadores() {
  digitalWrite(PIN_BOMBA, RELE_DESLIGADO);
  digitalWrite(PIN_VALVULA_1, RELE_DESLIGADO);
  digitalWrite(PIN_VALVULA_2, RELE_DESLIGADO);
}

void registrarEvento(const String& evento) {
  ultimoEvento = evento;
  Serial.println("[EVENTO] " + evento);
}

bool valvulaValida(uint8_t valvula) {
  return valvula == 1 || valvula == 2;
}

bool iniciarIrrigacao(uint8_t valvula, uint32_t segundos, const String& origem) {
  if (!valvulaValida(valvula)) return false;
  if (leituras.semAgua) {
    registrarEvento("irrigacao_bloqueada_sem_agua");
    return false;
  }

  desligarAtuadores();
  digitalWrite(valvula == 1 ? PIN_VALVULA_1 : PIN_VALVULA_2, RELE_LIGADO);
  digitalWrite(PIN_BOMBA, RELE_LIGADO);
  irrigacao = {true, valvula, millis(), segundos * 1000UL};
  registrarEvento(origem + "_iniciada_valvula_" + String(valvula));
  return true;
}

void finalizarIrrigacao(const String& motivo) {
  if (!irrigacao.ativa) return;
  desligarAtuadores();
  irrigacao.ativa = false;
  registrarEvento("irrigacao_finalizada_" + motivo);
}

void atualizarSensores() {
  if (millis() - ultimaLeitura < INTERVALO_SENSORES_MS) return;
  ultimaLeitura = millis();

  if (SIMULAR_SENSORES) {
    float fase = millis() / 60000.0f;
    leituras.temperatura = 24.0f + sin(fase) * 2.0f;
    leituras.umidadeAr = 62.0f + sin(fase * 0.7f) * 8.0f;
    leituras.pressao = 1013.0f + sin(fase * 0.2f) * 4.0f;
    leituras.luminosidade = max(0.0f, 4200.0f + sin(fase * 1.4f) * 1800.0f);
    leituras.umidadeSolo = 52.0f + sin(fase * 0.35f) * 8.0f;
    leituras.semAgua = false;
  } else {
    // Reservado para a leitura real dos sensores na proxima etapa.
    leituras.umidadeSolo = analogRead(PIN_SOLO) / 4095.0f * 100.0f;
    leituras.semAgua = digitalRead(PIN_BOIA) == BOIA_SEM_AGUA;
  }
}

void salvarConfiguracao() {
  JsonDocument documento;
  documento["modo"] = modoTexto(configuracao.modo);
  documento["intervalo_dias"] = configuracao.intervaloDias;
  JsonArray horarios = documento["horarios"].to<JsonArray>();
  for (uint8_t i = 0; i < MAX_HORARIOS; i++) {
    JsonObject item = horarios.add<JsonObject>();
    item["habilitado"] = configuracao.horarios[i].habilitado;
    item["hora"] = configuracao.horarios[i].hora;
    item["minuto"] = configuracao.horarios[i].minuto;
    item["duracao"] = configuracao.horarios[i].duracao;
    item["valvula"] = configuracao.horarios[i].valvula;
  }
  String texto;
  serializeJson(documento, texto);
  preferences.putString("config", texto);
}

void carregarConfiguracao() {
  String texto = preferences.getString("config", "");
  if (texto.isEmpty()) return;
  JsonDocument documento;
  if (deserializeJson(documento, texto)) return;
  configuracao.modo = textoModo(documento["modo"] | "inteligente");
  configuracao.intervaloDias = documento["intervalo_dias"] | 1;
  JsonArray horarios = documento["horarios"].as<JsonArray>();
  uint8_t total = min((size_t)MAX_HORARIOS, horarios.size());
  for (uint8_t i = 0; i < total; i++) {
    JsonObject item = horarios[i];
    configuracao.horarios[i].habilitado = item["habilitado"] | false;
    configuracao.horarios[i].hora = item["hora"] | 8;
    configuracao.horarios[i].minuto = item["minuto"] | 0;
    configuracao.horarios[i].duracao = item["duracao"] | 30;
    configuracao.horarios[i].valvula = item["valvula"] | 1;
  }
}

void jsonLeituras(JsonDocument& documento) {
  documento["temperatura"] = leituras.temperatura;
  documento["umidade_ar"] = leituras.umidadeAr;
  documento["pressao"] = leituras.pressao;
  documento["luminosidade"] = leituras.luminosidade;
  documento["umidade_solo"] = leituras.umidadeSolo;
  documento["sem_agua"] = leituras.semAgua;
  documento["sensores_simulados"] = SIMULAR_SENSORES;
}

void jsonConfiguracao(JsonDocument& documento) {
  documento["modo"] = modoTexto(configuracao.modo);
  documento["intervalo_dias"] = configuracao.intervaloDias;
  JsonArray horarios = documento["horarios"].to<JsonArray>();
  for (uint8_t i = 0; i < MAX_HORARIOS; i++) {
    JsonObject item = horarios.add<JsonObject>();
    item["indice"] = i;
    item["habilitado"] = configuracao.horarios[i].habilitado;
    item["hora"] = configuracao.horarios[i].hora;
    item["minuto"] = configuracao.horarios[i].minuto;
    item["duracao"] = configuracao.horarios[i].duracao;
    item["valvula"] = configuracao.horarios[i].valvula;
  }
}

void rotaTelemetria() {
  JsonDocument documento;
  documento["ok"] = true;
  documento["device_id"] = WiFi.macAddress();
  documento["plant_id"] = preferences.getString("plant_id", "");
  jsonLeituras(documento["sensores"].to<JsonObject>());
  documento["irrigacao_ativa"] = irrigacao.ativa;
  documento["valvula_ativa"] = irrigacao.valvula;
  documento["ultimo_evento"] = ultimoEvento;
  responderJson(200, documento);
}

void rotaConfiguracao() {
  if (server.method() == HTTP_GET) {
    JsonDocument documento;
    jsonConfiguracao(documento);
    responderJson(200, documento);
    return;
  }
  JsonDocument documento;
  if (deserializeJson(documento, server.arg("plain"))) {
    responderErro(400, "JSON invalido");
    return;
  }
  if (documento["modo"].is<const char*>()) configuracao.modo = textoModo(documento["modo"]);
  configuracao.intervaloDias = documento["intervalo_dias"] | configuracao.intervaloDias;
  JsonArray horarios = documento["horarios"].as<JsonArray>();
  if (!horarios.isNull()) {
    uint8_t total = min((size_t)MAX_HORARIOS, horarios.size());
    for (uint8_t i = 0; i < total; i++) {
      JsonObject item = horarios[i];
      configuracao.horarios[i].habilitado = item["habilitado"] | false;
      configuracao.horarios[i].hora = item["hora"] | 8;
      configuracao.horarios[i].minuto = item["minuto"] | 0;
      configuracao.horarios[i].duracao = item["duracao"] | 30;
      configuracao.horarios[i].valvula = item["valvula"] | 1;
    }
  }
  salvarConfiguracao();
  JsonDocument resposta;
  resposta["ok"] = true;
  responderJson(200, resposta);
}

void rotaComando() {
  JsonDocument documento;
  if (deserializeJson(documento, server.arg("plain"))) {
    responderErro(400, "JSON invalido");
    return;
  }
  String acao = documento["acao"] | "";
  if (acao == "parar" || acao == "emergency_stop") {
    finalizarIrrigacao("comando");
    JsonDocument resposta; resposta["ok"] = true; responderJson(200, resposta); return;
  }
  if (acao != "iniciar") { responderErro(400, "Acao deve ser iniciar ou parar"); return; }
  uint8_t valvula = documento["valvula"] | 1;
  uint32_t duracao = documento["duracao_segundos"] | 30;
  if (!iniciarIrrigacao(valvula, duracao, "manual")) {
    responderErro(409, leituras.semAgua ? "Sem agua no reservatorio" : "Nao foi possivel iniciar");
    return;
  }
  JsonDocument resposta; resposta["ok"] = true; responderJson(200, resposta);
}

void rotaEventos() {
  JsonDocument documento;
  documento["ultimo_evento"] = ultimoEvento;
  documento["irrigacao_ativa"] = irrigacao.ativa;
  responderJson(200, documento);
}

void rotaReset() {
  preferences.clear();
  desligarAtuadores();
  JsonDocument documento; documento["ok"] = true; documento["mensagem"] = "Configuracao apagada";
  responderJson(200, documento);
  delay(300);
  ESP.restart();
}

void rotaNaoEncontrada() { responderErro(404, "Rota nao encontrada"); }

void iniciarPontoDeAcesso() {
  String sufixo = String((uint32_t)(ESP.getEfuseMac() & 0xFFFF), HEX);
  sufixo.toUpperCase();
  String nome = "Irrigacao_Setup_" + sufixo;
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP(nome.c_str(), "irrigacao123");
  Serial.println("AP: " + nome);
  Serial.println("Senha: irrigacao123");
  Serial.println("IP do AP: " + WiFi.softAPIP().toString());
}

bool conectarWiFiSalvo() {
  String ssid = preferences.getString("ssid", "");
  String senha = preferences.getString("senha", "");
  if (ssid.isEmpty()) return false;
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid.c_str(), senha.c_str());
  Serial.print("Conectando ao Wi-Fi");
  uint32_t inicio = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - inicio < 15000) {
    delay(300); Serial.print('.');
  }
  Serial.println();
  if (WiFi.status() != WL_CONNECTED) return false;
  Serial.println("Wi-Fi conectado: " + WiFi.localIP().toString());
  configTime(-3 * 3600, 0, "pool.ntp.org", "time.nist.gov");
  return true;
}

void iniciarMDNS() {
  if (MDNS.begin("irrigacao-esp32")) {
    MDNS.addService("http", "tcp", 80);
    Serial.println("mDNS ativo: http://irrigacao-esp32.local");
  } else {
    Serial.println("Nao foi possivel iniciar o mDNS");
  }
}

void rotaRedes() {
  int quantidade = WiFi.scanNetworks();
  JsonDocument documento;
  JsonArray redes = documento["redes"].to<JsonArray>();
  for (int i = 0; i < quantidade; i++) {
    JsonObject rede = redes.add<JsonObject>();
    rede["ssid"] = WiFi.SSID(i);
    rede["sinal"] = WiFi.RSSI(i);
    rede["segura"] = WiFi.encryptionType(i) != WIFI_AUTH_OPEN;
  }
  responderJson(200, documento);
}

void rotaSalvarRede() {
  JsonDocument documento;
  if (deserializeJson(documento, server.arg("plain"))) {
    responderErro(400, "JSON invalido"); return;
  }
  String ssid = documento["ssid"] | "";
  if (ssid.isEmpty()) { responderErro(400, "SSID obrigatorio"); return; }
  preferences.putString("ssid", ssid);
  preferences.putString("senha", documento["senha"] | "");
  preferences.putString("device_token", documento["device_token"] | "");
  preferences.putString("plant_id", documento["plant_id"] | "");
  JsonDocument resposta; resposta["ok"] = true; resposta["mensagem"] = "Rede salva; reiniciando";
  responderJson(200, resposta);
  delay(500); ESP.restart();
}

void configurarRotas() {
  server.on("/networks", HTTP_GET, rotaRedes);
  server.on("/config", HTTP_POST, rotaSalvarRede);
  server.on("/api/telemetry", HTTP_GET, rotaTelemetria);
  server.on("/api/config", HTTP_GET, rotaConfiguracao);
  server.on("/api/config", HTTP_POST, rotaConfiguracao);
  server.on("/api/command", HTTP_POST, rotaComando);
  server.on("/api/events", HTTP_GET, rotaEventos);
  server.on("/api/reset", HTTP_POST, rotaReset);
  server.onNotFound(rotaNaoEncontrada);
  server.begin();
}

bool horarioPodeExecutar(uint8_t indice, const tm& agora) {
  Horario& horario = configuracao.horarios[indice];
  if (!horario.habilitado || horario.hora != agora.tm_hour || horario.minuto != agora.tm_min) return false;
  int identificador = agora.tm_yday * MAX_HORARIOS + indice;
  if (identificador == ultimoHorarioExecutado) return false;
  ultimoHorarioExecutado = identificador;
  return true;
}

void processarProgramacao() {
  if (irrigacao.ativa || configuracao.modo == Modo::Manual) return;
  time_t agoraUnix = time(nullptr);
  if (agoraUnix < 100000) return;
  tm agora;
  localtime_r(&agoraUnix, &agora);
  for (uint8_t i = 0; i < MAX_HORARIOS; i++) {
    if (horarioPodeExecutar(i, agora)) {
      Horario& horario = configuracao.horarios[i];
      iniciarIrrigacao(horario.valvula, horario.duracao,
                       configuracao.modo == Modo::Inteligente ? "inteligente" : "programado");
      break;
    }
  }
}

void processarIrrigacaoAtiva() {
  if (irrigacao.ativa && millis() - irrigacao.inicio >= irrigacao.duracao) {
    finalizarIrrigacao("tempo_encerrado");
  }
}

void enviarTelemetriaNuvem() {
  if (String(CLOUD_API_BASE_URL).isEmpty() || WiFi.status() != WL_CONNECTED) return;
  if (millis() - ultimoEnvio < INTERVALO_NUVEM_MS) return;
  ultimoEnvio = millis();
  JsonDocument documento;
  documento["device_id"] = WiFi.macAddress();
  documento["plant_id"] = preferences.getString("plant_id", "");
  jsonLeituras(documento["sensores"].to<JsonObject>());
  documento["irrigacao_ativa"] = irrigacao.ativa;
  String corpo; serializeJson(documento, corpo);
  HTTPClient http;
  http.begin(String(CLOUD_API_BASE_URL) + "/telemetry");
  http.addHeader("Content-Type", "application/json");
  String token = preferences.getString("device_token", "");
  if (!token.isEmpty()) http.addHeader("Authorization", "Bearer " + token);
  int codigo = http.POST(corpo);
  Serial.printf("Telemetria enviada: HTTP %d\n", codigo);
  http.end();
}

void setup() {
  Serial.begin(115200);
  delay(300);
  pinMode(PIN_BOMBA, OUTPUT);
  pinMode(PIN_VALVULA_1, OUTPUT);
  pinMode(PIN_VALVULA_2, OUTPUT);
  pinMode(PIN_SOLO, INPUT);
  pinMode(PIN_BOIA, INPUT_PULLUP);
  desligarAtuadores();

  Wire.begin(PIN_SDA, PIN_SCL);
  Serial.println("I2C iniciado: SDA GPIO21 / SCL GPIO22");
  Serial.println("BME280 esperado em 0x76; VEML7700 esperado em 0x10");

  preferences.begin("irrigacao", false);
  carregarConfiguracao();
  if (!conectarWiFiSalvo()) iniciarPontoDeAcesso();
  iniciarMDNS();
  configurarRotas();
  Serial.println("Firmware pronto. Sensores simulados: " + String(SIMULAR_SENSORES ? "SIM" : "NAO"));
}

void loop() {
  server.handleClient();
  atualizarSensores();
  processarIrrigacaoAtiva();
  processarProgramacao();
  enviarTelemetriaNuvem();
  delay(2);
}

// Firmware de exemplo — Plantinha
//
// O ESP32 fica só falando com o computador via cabo USB (Serial), sem
// precisar de Wi-Fi: é o navegador que lê essa porta serial (Web Serial
// API) e manda os dados pro Supabase, já sabendo de qual planta é o
// sensor (você escolhe isso na hora de conectar, no site).
//
// Protocolo (bem simples, uma linha = uma mensagem):
//   ESP32 -> PC: {"soil_moisture":42,"temperature":24.1}\n   (a cada poucos segundos)
//   PC -> ESP32: WATER\n                                     (aciona a bomba/relé)
//
// Ajuste os pinos abaixo conforme sua montagem.

const int PINO_SENSOR_UMIDADE = 34; // entrada analógica do sensor capacitivo
const int PINO_BOMBA = 26;          // saída digital para o relé/MOSFET da bomba
const unsigned long INTERVALO_LEITURA_MS = 5000;
const unsigned long TEMPO_BOMBA_LIGADA_MS = 3000;

// Calibre estes valores com o seu sensor: leitura no ar seco e leitura
// submerso em água, para converter a leitura bruta em porcentagem.
const int LEITURA_SECO = 3000;
const int LEITURA_MOLHADO = 1200;

unsigned long ultimaLeitura = 0;

void setup() {
  Serial.begin(115200);
  pinMode(PINO_BOMBA, OUTPUT);
  digitalWrite(PINO_BOMBA, LOW);
}

float lerUmidadePercentual() {
  int bruto = analogRead(PINO_SENSOR_UMIDADE);
  float pct = (float)(LEITURA_SECO - bruto) / (float)(LEITURA_SECO - LEITURA_MOLHADO) * 100.0;
  if (pct < 0) pct = 0;
  if (pct > 100) pct = 100;
  return pct;
}

void acionarBomba() {
  digitalWrite(PINO_BOMBA, HIGH);
  delay(TEMPO_BOMBA_LIGADA_MS);
  digitalWrite(PINO_BOMBA, LOW);
}

void enviarLeitura() {
  float umidade = lerUmidadePercentual();
  // Troque por um sensor de temperatura real (ex.: DHT22) se tiver um.
  float temperatura = 24.0;

  Serial.print("{\"soil_moisture\":");
  Serial.print(umidade, 1);
  Serial.print(",\"temperature\":");
  Serial.print(temperatura, 1);
  Serial.println("}");
}

void processarComando(const String& linha) {
  if (linha == "WATER") {
    acionarBomba();
  }
}

void loop() {
  unsigned long agora = millis();
  if (agora - ultimaLeitura >= INTERVALO_LEITURA_MS) {
    ultimaLeitura = agora;
    enviarLeitura();
  }

  if (Serial.available()) {
    String linha = Serial.readStringUntil('\n');
    linha.trim();
    if (linha.length() > 0) {
      processarComando(linha);
    }
  }
}

# Irrigação Inteligente

Aplicativo Flutter do TCC para monitoramento e controle de uma horta por meio de um ESP32. O projeto está em fase de protótipo de interface: sensores, IA, ESP32 e notificações ainda utilizam dados simulados.

## Contexto do aplicativo

O aplicativo permite cadastrar e acompanhar plantas, configurar cuidados e controlar a irrigação. O fluxo principal é:

1. Cadastrar a planta por foto ou por nome popular/científico.
2. Escolher configurações sugeridas pela IA ou personalizar os cuidados.
3. Configurar o modo de irrigação: **Manual**, **Programado** ou **Inteligente**.
4. Configurar a conexão Wi-Fi do ESP32 por um fluxo simulado de Access Point.

Áreas principais:

- **Início:** dashboard com umidade do solo, temperatura, umidade do ar, luminosidade, próxima rega e modo atual.
- **Controle:** alteração do modo e dos parâmetros da planta selecionada.
- **Planta:** edição da identificação, configuração do ESP32, notificações e exclusão.
- **Histórico:** gráficos simulados de sensores e registros de irrigações.

O sistema prevê notificações configuráveis de irrigação realizada, luminosidade excedente, estresse térmico, solo seco, clima seco, fim da rega manual e trava de segurança. Alertas críticos — reservatório vazio, corte de emergência, perda de conexão e anomalias dos sensores — serão automáticos e não poderão ser desativados.

## Requisitos para desenvolvimento

Para executar no Android, instale Flutter **3.47.9 ou superior** no canal stable, Android Studio, Android SDK Platform **37**, Build-Tools, Command-line Tools, Platform-Tools, Android Emulator (se necessário), Java/JDK **17** e Git.

O Visual Studio não é necessário para executar no Android. Ele só é necessário para executar como desktop Windows.

```powershell
flutter doctor
flutter doctor -v
```

Se o Flutter não localizar o Android SDK:

```powershell
flutter config --android-sdk "$env:LOCALAPPDATA\Android\Sdk"
flutter doctor --android-licenses
```

## Instalação

```powershell
git clone <URL_DO_REPOSITORIO>
cd TCC_App
flutter pub get
```

O comando `flutter pub get` instala todas as dependências declaradas no `pubspec.yaml`, incluindo gerenciamento de estado, rotas, Supabase, HTTP, câmera, permissões, notificações, gráficos, persistência local e conectividade.

## Executando no Android

```powershell
flutter emulators
flutter emulators --launch <ID_DO_EMULADOR>
flutter devices
flutter run -d <ID_DO_DISPOSITIVO>
```

Exemplo:

```powershell
flutter run -d emulator-5554
```

Para executar no navegador:

```powershell
flutter run -d chrome
```

### Executar conectado ao Supabase

O cliente Supabase é inicializado quando as variáveis abaixo são informadas.
Use apenas a chave publicável no aplicativo; nunca use uma chave `secret` ou
`service_role` no Flutter.

No PowerShell:

```powershell
flutter run -d emulator-5554 `
  --dart-define=SUPABASE_URL=https://SEU_PROJETO.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=SUA_CHAVE_PUBLICAVEL
```

Sem esses parâmetros, o app continua abrindo em modo simulado.

Para trabalhar com migrations pela CLI, o projeto já possui a pasta
`supabase/` inicializada. A CLI pode ser executada sem instalação global:

```powershell
npx supabase --version
npx supabase init
```

O comando `supabase link` só deve ser executado depois de autenticar a CLI e
informar o project ref do painel Supabase. Não coloque tokens de acesso no
repositório.

## Primeiro acesso e dados simulados

No primeiro acesso, o aplicativo abre o processo de cadastro da planta. As configurações são salvas localmente no `SharedPreferences`.

Para limpar as plantas e reiniciar o teste no emulador Android:

```powershell
adb shell pm clear com.tcc.irrigacao_inteligente
```

Se `adb` não estiver no PATH do Windows:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" shell pm clear com.tcc.irrigacao_inteligente
```

## Comandos úteis

```powershell
flutter analyze
flutter test
flutter clean
flutter pub get
.\android\gradlew.bat --stop
```

## Estrutura do projeto

```text
lib/app/                 # Tema e inicialização
lib/core/                # Configurações e erros compartilhados
lib/data/                # Repositórios e serviços
lib/domain/              # Modelos e contratos de negócio
lib/features/mock_ui/    # Fluxos e telas simuladas atuais
android/                 # Configuração Android e Gradle
ios/                     # Configuração iOS
test/                    # Testes automatizados
pubspec.yaml             # Dependências Flutter
```

## Observações

- Os valores dos sensores são simulados.
- A conexão real com o ESP32 ainda não está implementada.
- A identificação por IA é representada por opções simuladas.
- O fluxo de Wi-Fi e Access Point é demonstrativo.
- Não inclua chaves, senhas ou credenciais no código versionado. Para integrações reais, utilize variáveis de ambiente ou `--dart-define`.

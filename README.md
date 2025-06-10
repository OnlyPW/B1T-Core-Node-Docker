# B1T Core Node - Standalone Docker Project

Ein eigenständiges Docker-Projekt für den B1T Core Node, das als vollständige Blockchain-Node für das B1T-Netzwerk fungiert.

## 🚀 Features

- **Vollständige B1T Core Node** mit automatischem Download der neuesten Version (v2.1.0.0)
- **RPC-Server** für externe API-Zugriffe
- **Persistent Storage** für Blockchain-Daten
- **Health Monitoring** mit automatischen Checks
- **Sicherheit** durch Non-Root User Execution
- **IPv6 Support** für moderne Netzwerk-Infrastrukturen
- **Transaction Indexing** für erweiterte Abfragen

## 📋 Voraussetzungen

- Docker Engine 20.10+
- Docker Compose 2.0+
- Mindestens 4GB RAM
- Mindestens 50GB freier Speicherplatz für Blockchain-Daten

## 🛠️ Installation

### 1. Repository klonen
```bash
git clone https://github.com/OnlyPW/B1T-Core-Node-Docker.git
cd B1T-Core-Node-Docker
```

### 2. Umgebungsvariablen konfigurieren
```bash
cp .env.example .env
```

Bearbeiten Sie die `.env` Datei nach Ihren Bedürfnissen:
```env
# RPC Zugangsdaten
RPC_USER=b1tuser
RPC_PASSWORD=your_secure_password_here

# Netzwerk Ports
RPC_PORT=33318
P2P_PORT=33317

# Debugging (für Produktion auf 0 setzen)
DEBUG_LEVEL=1
```
!!!AutoSetup!!!
chmod u+x install.sh
./install.sh

### 3. Node starten
```bash
# Mit Docker Compose (empfohlen)
docker-compose up -d

# Oder direkt mit Docker
docker build -t b1t-core-node .
docker run -d \
  --name b1t-core \
  -p 33318:33318 \
  -p 33317:33317 \
  -v b1t_data:/home/b1t/.b1t \
  -e RPC_USER=b1tuser \
  -e RPC_PASSWORD=your_password \
  b1t-core-node
```

## 📊 Überwachung

### Status prüfen
```bash
# Container Status
docker-compose ps

# Logs anzeigen
docker-compose logs -f

# Blockchain Info abrufen
docker-compose exec b1t-core b1t-cli getblockchaininfo
```

### RPC-API testen
```bash
# Netzwerk-Informationen
curl -u b1tuser:your_password \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"1.0","id":"test","method":"getnetworkinfo","params":[]}' \
  http://localhost:33318/

# Aktuelle Blockhöhe
curl -u b1tuser:your_password \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"1.0","id":"test","method":"getblockcount","params":[]}' \
  http://localhost:33318/
```

## 🔧 Konfiguration

### RPC-Einstellungen
- **Port**: 33318 (konfigurierbar über RPC_PORT)
- **Bind**: 0.0.0.0 (alle Interfaces)
- **Authentifizierung**: Username/Password
- **Erlaubte IPs**: Docker-Netzwerk + lokale Netzwerke

### P2P-Netzwerk
- **Port**: 33317 (konfigurierbar über P2P_PORT)
- **IPv4 & IPv6**: Vollständig unterstützt
- **UPnP**: Aktiviert für automatische Port-Weiterleitung

### Erweiterte Features
- **Transaction Index**: Aktiviert für vollständige TX-Suche
- **Address Index**: Aktiviert für Adress-basierte Abfragen
- **Wallet**: Optional aktivierbar
- **ZMQ**: Vorbereitet für Real-time Notifications

## 🔒 Sicherheit

- **Non-Root Execution**: Container läuft als `b1t` User
- **Netzwerk-Isolation**: RPC nur über definierte Netzwerke erreichbar
- **Sichere Defaults**: Konservative Konfiguration out-of-the-box
- **Credential Management**: Umgebungsvariablen für sensible Daten

## 📁 Datenverzeichnisse

- **Container**: `/home/b1t/.b1t`
- **Volume**: `b1t_data`
- **Konfiguration**: `/home/b1t/.b1t/b1t.conf`
- **Logs**: `/home/b1t/.b1t/debug.log`

## 🚨 Troubleshooting

### Häufige Probleme

**Container startet nicht:**
```bash
# Logs prüfen
docker-compose logs b1t-core

# Port-Konflikte prüfen
netstat -tulpn | grep :33318
```

**RPC-Verbindung fehlgeschlagen:**
```bash
# Credentials prüfen
cat .env | grep RPC

# Node-Status prüfen
docker-compose exec b1t-core b1t-cli getinfo
```

**Synchronisation langsam:**
```bash
# Peer-Verbindungen prüfen
docker-compose exec b1t-core b1t-cli getpeerinfo

# Netzwerk-Status
docker-compose exec b1t-core b1t-cli getnetworkinfo
```

## 🔄 Updates

```bash
# Neue Version deployen
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Daten bleiben durch Volumes erhalten
```

## 📚 API-Dokumentation

Die vollständige RPC-API Dokumentation finden Sie in der [B1T Core RPC Documentation](docs/rpc-api.md).

### Wichtige Endpoints

- `getblockchaininfo` - Blockchain-Status
- `getnetworkinfo` - Netzwerk-Informationen
- `getblock <hash>` - Block-Details
- `getrawtransaction <txid>` - Transaction-Details
- `getaddressbalance <address>` - Adress-Guthaben

## 🤝 Contributing

1. Fork das Repository
2. Erstellen Sie einen Feature Branch
3. Committen Sie Ihre Änderungen
4. Pushen Sie zum Branch
5. Öffnen Sie einen Pull Request

## 📄 Lizenz

MIT License - siehe [LICENSE](LICENSE) für Details.

---

**Hinweis**: Dieses Projekt ist für Entwicklungs- und Testzwecke optimiert. Für Produktionsumgebungen sollten zusätzliche Sicherheitsmaßnahmen implementiert werden.

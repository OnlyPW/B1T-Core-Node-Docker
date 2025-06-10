# B1T Core Node - Docker Setup

Einfache Docker-Installation für den B1T Core Node.

## 🚀 Schnelle Installation

```bash
# 1. Repository klonen
git clone https://github.com/OnlyPW/B1T-Core-Node-Docker.git
cd B1T-Core-Node-Docker

# 2. Installation starten
chmod u+x install.sh
./install.sh
```

**Das war's!** Das Skript installiert automatisch Docker (falls nötig) und startet den B1T Core Node.

## 📋 Voraussetzungen

- Linux-System (Ubuntu, Debian, CentOS, RHEL, Fedora)
- Mindestens 4GB RAM
- Mindestens 50GB freier Speicherplatz
- Sudo-Berechtigung (für Docker-Installation)

## 🔧 Was passiert automatisch?

- ✅ Docker-Installation (falls nicht vorhanden)
- ✅ Docker Compose-Installation
- ✅ Umgebungskonfiguration (.env)
- ✅ Zufällige RPC-Passwort-Generierung
- ✅ Container-Build und -Start
- ✅ Gesundheitsprüfungen
- ✅ Anzeige der RPC-Zugangsdaten

## 🛠️ Manuelle Befehle

Nach der Installation stehen folgende Befehle zur Verfügung:

```bash
# Status prüfen
docker compose ps

# Logs anzeigen
docker compose logs -f

# Node-Informationen
docker exec -it b1t-core-node b1t-cli getblockchaininfo

# Node stoppen
docker compose down

# Node neustarten
docker compose restart
```

## 🔧 Optionen für install.sh

```bash
./install.sh --help          # Hilfe anzeigen
./install.sh --check         # Docker-Installation prüfen
./install.sh --clean         # Saubere Installation (entfernt alte Daten)
./install.sh --build-only    # Nur bauen, nicht starten
./install.sh --start-only    # Nur starten (bereits gebaut)
```

## 📊 Standard-Konfiguration

- **RPC-Port**: 33318
- **P2P-Port**: 33317
- **RPC-Benutzer**: b1tuser
- **RPC-Passwort**: Automatisch generiert
- **Datenverzeichnis**: ./data
- **Logs**: ./logs

## 🚨 Problemlösung

**Bei Problemen:**
1. Prüfen Sie die Logs: `docker compose logs -f`
2. Verwenden Sie Clean-Installation: `./install.sh --clean`
3. Stellen Sie sicher, dass die Ports 33317 und 33318 frei sind

## 📄 Lizenz

MIT License - siehe [LICENSE](LICENSE) für Details.

---

**Hinweis**: Dieses Projekt ist für Entwicklungs- und Testzwecke optimiert. Für Produktionsumgebungen sollten zusätzliche Sicherheitsmaßnahmen implementiert werden.

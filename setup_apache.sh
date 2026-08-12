#!/usr/bin/env bash
#
# setup_apache.sh - Installiert und konfiguriert automatisch einen Apache Webserver
#
# Unterstuetzt Debian/Ubuntu (apt) sowie RHEL/CentOS/Rocky/AlmaLinux/Fedora (dnf/yum).
# Das Skript ist idempotent: es kann mehrfach ausgefuehrt werden.
#
# Aufruf:
#   sudo ./setup_apache.sh [-d DOMAIN] [-r DOCROOT] [-p PORT] [-e EMAIL]
#
# Optionen:
#   -d DOMAIN    ServerName / Domain fuer den VirtualHost   (Default: localhost)
#   -r DOCROOT   Document-Root Verzeichnis                  (Default: /var/www/<DOMAIN>)
#   -p PORT      Port auf dem Apache lauscht                (Default: 80)
#   -e EMAIL     ServerAdmin E-Mail-Adresse                 (Default: webmaster@<DOMAIN>)
#   -h           Diese Hilfe anzeigen
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Standardwerte
# ---------------------------------------------------------------------------
DOMAIN="localhost"
DOCROOT=""
PORT="80"
EMAIL=""

# ---------------------------------------------------------------------------
# Hilfsfunktionen fuer farbige Ausgaben
# ---------------------------------------------------------------------------
log()   { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[1;32m[ OK ]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*" >&2; }
error() { printf '\033[1;31m[FEHLER]\033[0m %s\n' "$*" >&2; }

die() { error "$*"; exit 1; }

usage() {
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

# ---------------------------------------------------------------------------
# Argumente parsen
# ---------------------------------------------------------------------------
while getopts ":d:r:p:e:h" opt; do
    case "$opt" in
        d) DOMAIN="$OPTARG" ;;
        r) DOCROOT="$OPTARG" ;;
        p) PORT="$OPTARG" ;;
        e) EMAIL="$OPTARG" ;;
        h) usage ;;
        :)  die "Option -$OPTARG benoetigt einen Wert." ;;
        \?) die "Unbekannte Option: -$OPTARG (nutze -h fuer Hilfe)." ;;
    esac
done

# Abgeleitete Defaults
[ -n "$DOCROOT" ] || DOCROOT="/var/www/${DOMAIN}"
[ -n "$EMAIL" ]   || EMAIL="webmaster@${DOMAIN}"

# Port validieren
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    die "Ungueltiger Port: $PORT"
fi

# ---------------------------------------------------------------------------
# Vorbedingungen
# ---------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    die "Dieses Skript muss als root bzw. mit sudo ausgefuehrt werden."
fi

# ---------------------------------------------------------------------------
# Distribution / Paketmanager erkennen
# ---------------------------------------------------------------------------
detect_distro() {
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_LIKE="${ID_LIKE:-}"
    else
        die "Kann /etc/os-release nicht lesen - Distribution unbekannt."
    fi

    if command -v apt-get >/dev/null 2>&1; then
        PKG_FAMILY="debian"
        APACHE_PKG="apache2"
        APACHE_SVC="apache2"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_FAMILY="rhel"
        PKG_MGR="dnf"
        APACHE_PKG="httpd"
        APACHE_SVC="httpd"
    elif command -v yum >/dev/null 2>&1; then
        PKG_FAMILY="rhel"
        PKG_MGR="yum"
        APACHE_PKG="httpd"
        APACHE_SVC="httpd"
    else
        die "Kein unterstuetzter Paketmanager (apt/dnf/yum) gefunden."
    fi

    log "Erkannte Distribution: ${DISTRO_ID} (Familie: ${PKG_FAMILY})"
}

# ---------------------------------------------------------------------------
# Apache installieren
# ---------------------------------------------------------------------------
install_apache() {
    log "Installiere Apache (${APACHE_PKG}) ..."
    if [ "$PKG_FAMILY" = "debian" ]; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y "$APACHE_PKG"
    else
        "$PKG_MGR" install -y "$APACHE_PKG"
    fi
    ok "Apache installiert."
}

# ---------------------------------------------------------------------------
# Document-Root und Beispielseite anlegen
# ---------------------------------------------------------------------------
setup_docroot() {
    log "Lege Document-Root an: ${DOCROOT}"
    mkdir -p "$DOCROOT"

    cat > "${DOCROOT}/index.html" <<HTML
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Willkommen auf ${DOMAIN}</title>
    <style>
        body { font-family: system-ui, sans-serif; margin: 4rem auto; max-width: 40rem;
               line-height: 1.6; color: #222; padding: 0 1rem; }
        h1 { color: #c9302c; }
        code { background: #f4f4f4; padding: .1rem .3rem; border-radius: 3px; }
    </style>
</head>
<body>
    <h1>Es funktioniert! &#127881;</h1>
    <p>Der Apache Webserver auf <strong>${DOMAIN}</strong> laeuft erfolgreich.</p>
    <p>Dieses Verzeichnis: <code>${DOCROOT}</code></p>
    <p>Erstellt am $(date '+%Y-%m-%d %H:%M:%S') durch <code>setup_apache.sh</code>.</p>
</body>
</html>
HTML

    # Rechte / Besitzer je nach Distribution setzen
    if [ "$PKG_FAMILY" = "debian" ]; then
        WEB_USER="www-data"; WEB_GROUP="www-data"
    else
        WEB_USER="apache"; WEB_GROUP="apache"
    fi
    chown -R "${WEB_USER}:${WEB_GROUP}" "$DOCROOT" 2>/dev/null || true
    chmod -R 755 "$DOCROOT"
    ok "Beispielseite erstellt unter ${DOCROOT}/index.html"
}

# ---------------------------------------------------------------------------
# VirtualHost konfigurieren
# ---------------------------------------------------------------------------
configure_vhost() {
    log "Konfiguriere VirtualHost fuer ${DOMAIN}:${PORT}"

    local vhost_conf
    if [ "$PKG_FAMILY" = "debian" ]; then
        vhost_conf="/etc/apache2/sites-available/${DOMAIN}.conf"
    else
        vhost_conf="/etc/httpd/conf.d/${DOMAIN}.conf"
    fi

    cat > "$vhost_conf" <<VHOST
<VirtualHost *:${PORT}>
    ServerName ${DOMAIN}
    ServerAdmin ${EMAIL}
    DocumentRoot ${DOCROOT}

    <Directory ${DOCROOT}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR:-/var/log/httpd}/${DOMAIN}_error.log
    CustomLog \${APACHE_LOG_DIR:-/var/log/httpd}/${DOMAIN}_access.log combined
</VirtualHost>
VHOST

    ok "VirtualHost geschrieben nach ${vhost_conf}"

    # Auf nicht-Standard-Port muss Apache zusaetzlich lauschen
    ensure_listen_port

    if [ "$PKG_FAMILY" = "debian" ]; then
        a2enmod rewrite  >/dev/null 2>&1 || true
        a2ensite "${DOMAIN}.conf" >/dev/null 2>&1 || true
        # Default-Seite deaktivieren, wenn wir localhost o.ae. bereitstellen
        a2dissite 000-default.conf >/dev/null 2>&1 || true
    fi
}

# ---------------------------------------------------------------------------
# Sicherstellen, dass Apache auf dem gewuenschten Port lauscht
# ---------------------------------------------------------------------------
ensure_listen_port() {
    [ "$PORT" = "80" ] && return 0

    local ports_file
    if [ "$PKG_FAMILY" = "debian" ]; then
        ports_file="/etc/apache2/ports.conf"
    else
        ports_file="/etc/httpd/conf/httpd.conf"
    fi

    if ! grep -qE "^[[:space:]]*Listen[[:space:]]+${PORT}([[:space:]]|$)" "$ports_file"; then
        echo "Listen ${PORT}" >> "$ports_file"
        log "Listen-Direktive fuer Port ${PORT} zu ${ports_file} hinzugefuegt."
    fi
}

# ---------------------------------------------------------------------------
# Firewall oeffnen (falls vorhanden)
# ---------------------------------------------------------------------------
configure_firewall() {
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
        log "Oeffne Port ${PORT} in ufw ..."
        ufw allow "${PORT}/tcp" >/dev/null 2>&1 || warn "ufw-Regel konnte nicht gesetzt werden."
        ok "ufw-Regel fuer Port ${PORT} gesetzt."
    elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
        log "Oeffne Port ${PORT} in firewalld ..."
        firewall-cmd --permanent --add-port="${PORT}/tcp" >/dev/null 2>&1 || warn "firewalld-Regel konnte nicht gesetzt werden."
        firewall-cmd --reload >/dev/null 2>&1 || true
        ok "firewalld-Regel fuer Port ${PORT} gesetzt."
    else
        warn "Keine aktive Firewall (ufw/firewalld) erkannt - Schritt uebersprungen."
    fi
}

# ---------------------------------------------------------------------------
# Konfiguration testen und Dienst starten
# ---------------------------------------------------------------------------
start_apache() {
    log "Pruefe Apache-Konfiguration ..."
    if [ "$PKG_FAMILY" = "debian" ]; then
        apache2ctl configtest || die "Konfigurationstest fehlgeschlagen."
    else
        httpd -t || die "Konfigurationstest fehlgeschlagen."
    fi
    ok "Konfiguration ist gueltig."

    log "Aktiviere und starte Dienst ${APACHE_SVC} ..."
    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable "$APACHE_SVC" >/dev/null 2>&1 || true
        systemctl restart "$APACHE_SVC"
        systemctl --no-pager --full status "$APACHE_SVC" | head -n 5 || true
    else
        service "$APACHE_SVC" restart || die "Dienst konnte nicht gestartet werden."
    fi
    ok "Apache laeuft."
}

# ---------------------------------------------------------------------------
# Abschluss-Zusammenfassung
# ---------------------------------------------------------------------------
summary() {
    echo
    ok "Apache Webserver erfolgreich eingerichtet!"
    echo "  --------------------------------------------------"
    echo "  Domain / ServerName : ${DOMAIN}"
    echo "  Port                : ${PORT}"
    echo "  Document-Root       : ${DOCROOT}"
    echo "  ServerAdmin         : ${EMAIL}"
    echo "  --------------------------------------------------"
    echo "  Test:  curl http://${DOMAIN}:${PORT}/"
    echo
}

# ---------------------------------------------------------------------------
# Hauptablauf
# ---------------------------------------------------------------------------
main() {
    detect_distro
    install_apache
    setup_docroot
    configure_vhost
    configure_firewall
    start_apache
    summary
}

main "$@"

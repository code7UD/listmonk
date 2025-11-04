#!/bin/sh

# Script d'entrée pour Listmonk avec extension géographique

set -e

echo "🚀 Démarrage de Listmonk avec extension géographique..."

# Créer un fichier de configuration avec les variables d'environnement
echo "📝 Création de la configuration..."
cat > config.toml << EOF
[app]
address = "${LISTMONK_APP_ADDRESS:-0.0.0.0:9000}"
admin_username = "${LISTMONK_APP_ADMIN_USERNAME:-admin}"
admin_password = "${LISTMONK_APP_ADMIN_PASSWORD:-admin123!}"

[db]
host = "${LISTMONK_DB_HOST:-postgres}"
port = ${LISTMONK_DB_PORT:-5432}
user = "${LISTMONK_DB_USER:-listmonk}"
password = "${LISTMONK_DB_PASSWORD:-listmonk}"
database = "${LISTMONK_DB_DATABASE:-listmonk}"
ssl_mode = "${LISTMONK_DB_SSL_MODE:-disable}"
max_open = 25
max_idle = 25
max_lifetime = "300s"

[geo]
enabled = true
auto_index = true
cache_ttl = "1h"
validate_insee = true

[importer]
batch_size = 1000
max_workers = 4

[security]
enable_captcha = false

[smtp]
host = "localhost"
port = 1025
auth_protocol = "none"
max_conns = 10
idle_timeout = "15s"
wait_timeout = "5s"
max_msg_retries = 2
tls_enabled = false

[upload]
provider = "filesystem"
filesystem_upload_path = "./uploads"
filesystem_upload_uri = "/uploads"

[privacy]
individual_tracking = false
unsubscribe_header = true
allow_blocklist = true
allow_export = true
allow_wipe = true
exportable = ["profile", "subscriptions", "campaign_views", "link_clicks"]

[bounce]
enabled = false
webhooks_enabled = false

[performance]
concurrency = 10
message_rate = 10
batch_size = 1000
max_send_errors = 1000
EOF

# Attendre que PostgreSQL soit prêt
echo "⏳ Attente de PostgreSQL..."
while ! pg_isready -h $LISTMONK_DB_HOST -p $LISTMONK_DB_PORT -U $LISTMONK_DB_USER; do
  echo "PostgreSQL n'est pas encore prêt. Attente..."
  sleep 2
done

echo "✅ PostgreSQL est prêt!"

# Vérifier si la base de données est initialisée
echo "🗄️ Initialisation de la base de données..."
if ! ./listmonk --config config.toml --install --idempotent --yes; then
  echo "❌ Erreur lors de l'initialisation de la base de données"
  exit 1
fi

echo "✅ Base de données initialisée"

# Exécuter les migrations géographiques si nécessaire
echo "🗺️ Application des migrations géographiques..."
if ! ./listmonk --config config.toml --upgrade --yes; then
  echo "❌ Erreur lors des migrations géographiques"
  exit 1
fi

echo "✅ Migrations géographiques appliquées"

# Importer les données de démonstration si demandé
if [ "$LISTMONK_IMPORT_DEMO_DATA" = "true" ] && [ -f "/listmonk/demo/demo_geo_data.csv" ]; then
  echo "📊 Import des données de démonstration..."
  if [ -f "/listmonk/scripts/import_demo_data.sh" ]; then
    /listmonk/scripts/import_demo_data.sh
  else
    echo "⚠️ Script d'import de démonstration non trouvé"
  fi
fi

echo "🎉 Listmonk avec extension géographique prêt!"

# Démarrer l'application
exec "$@"
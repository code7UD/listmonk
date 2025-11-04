#!/bin/sh

set -e

export PUID=${PUID:-0}
export PGID=${PGID:-0}
export GROUP_NAME="app"
export USER_NAME="app"

# This function evaluates if the supplied PGID is already in use
# if it is not in use, it creates the group with the PGID
# if it is in use, it sets the GROUP_NAME to the existing group
create_group() {
  if ! getent group ${PGID} > /dev/null 2>&1; then
    addgroup -g ${PGID} ${GROUP_NAME}
  else
    existing_group=$(getent group ${PGID} | cut -d: -f1)
    export GROUP_NAME=${existing_group}
  fi
}

# This function evaluates if the supplied PUID is already in use
# if it is not in use, it creates the user with the PUID and PGID
create_user() {
  if ! getent passwd ${PUID} > /dev/null 2>&1; then
    adduser -u ${PUID} -G ${GROUP_NAME} -s /bin/sh -D ${USER_NAME}
  else
    existing_user=$(getent passwd ${PUID} | cut -d: -f1)
    export USER_NAME=${existing_user}
  fi
}

# Run the needed functions to create the user and group
create_group
create_user

# Try to set the ownership of the app directory to the app user.
if ! chown -R ${PUID}:${PGID} /listmonk 2>/dev/null; then
  echo "Warning: Failed to change ownership of /listmonk. Readonly volume?"
fi

# Fonction pour générer le fichier config.toml
generate_config() {
    echo "📝 Génération du fichier config.toml..."
    
    cat > /listmonk/config.toml << EOF
[app]
address = "${LISTMONK_APP_ADDRESS:-0.0.0.0:9000}"
admin_username = "${LISTMONK_APP_ADMIN_USERNAME:-admin}"
admin_password = "${LISTMONK_APP_ADMIN_PASSWORD:-admin123}"

[db]
host = "${LISTMONK_DB_HOST:-postgres}"
port = ${LISTMONK_DB_PORT:-5432}
user = "${LISTMONK_DB_USER:-listmonk}"
password = "${LISTMONK_DB_PASSWORD:-listmonk_secure_password}"
database = "${LISTMONK_DB_DATABASE:-listmonk}"
ssl_mode = "${LISTMONK_DB_SSL_MODE:-disable}"
max_open = ${LISTMONK_DB_MAX_OPEN:-25}
max_idle = ${LISTMONK_DB_MAX_IDLE:-25}
max_lifetime = "${LISTMONK_DB_MAX_LIFETIME:-300s}"

[smtp]
[[smtp.host]]
enabled = false
host = "localhost"
port = 587
auth_protocol = "plain"
username = ""
password = ""
hello_hostname = ""
max_conns = 10
idle_timeout = "15s"
wait_timeout = "5s"
max_msg_retries = 2
tls_enabled = true
tls_skip_verify = false
email_headers = []

[upload]
provider = "filesystem"
filesystem.upload_path = "uploads"
filesystem.upload_uri = "/uploads"

[privacy]
individual_tracking = false
unsubscribe_header = true
allow_blocklist = true
allow_export = true
allow_wipe = true
exportable = ["profile", "subscriptions", "campaign_views", "link_clicks"]

[media]
upload.provider = "filesystem"
upload.filesystem.upload_path = "uploads"
upload.filesystem.upload_uri = "/uploads"
EOF

    echo "✅ Fichier config.toml généré"
}

# Fonction d'attente de PostgreSQL
wait_for_postgres() {
    echo "⏳ Attente de PostgreSQL..."
    
    # Utiliser nc si disponible, sinon utiliser une méthode alternative
    if command -v nc >/dev/null 2>&1; then
        until nc -z "${LISTMONK_DB_HOST:-postgres}" "${LISTMONK_DB_PORT:-5432}"; do
            echo "PostgreSQL n'est pas encore prêt - attente..."
            sleep 2
        done
    else
        # Méthode alternative sans nc
        until timeout 1 sh -c "echo > /dev/tcp/${LISTMONK_DB_HOST:-postgres}/${LISTMONK_DB_PORT:-5432}" 2>/dev/null; do
            echo "PostgreSQL n'est pas encore prêt - attente..."
            sleep 2
        done
    fi
    
    echo "✅ PostgreSQL est prêt"
}

# Générer la configuration si elle n'existe pas
if [ ! -f /listmonk/config.toml ]; then
    generate_config
fi

# Attendre PostgreSQL si on démarre listmonk
if [ "$1" = "./listmonk" ] || [ "$#" -eq 0 ]; then
    wait_for_postgres
fi

echo "Launching listmonk with user=[${USER_NAME}] group=[${GROUP_NAME}] PUID=[${PUID}] PGID=[${PGID}]"

# If running as root and PUID is not 0, then execute command as PUID
# this allows us to run the container as a non-root user
if [ "$(id -u)" = "0" ] && [ "${PUID}" != "0" ]; then
  su-exec ${PUID}:${PGID} "$@"
else
  exec "$@"
fi

# Dockerfile pour Listmonk avec extension géographique française
FROM golang:1.24-alpine AS builder

# Installer les dépendances de build
RUN apk add --no-cache git make build-base nodejs npm ca-certificates

# Définir le répertoire de travail
WORKDIR /src

# Copier les fichiers de dépendances Go
COPY go.mod go.sum ./
RUN go mod download

# Copier les fichiers source
COPY . .

# Construire le frontend
WORKDIR /src/frontend
# Créer un fichier .gitignore vide si il n'existe pas
RUN touch .gitignore
RUN npm install && npm run build

# Construire l'application Go
WORKDIR /src
RUN make build

# Image finale
FROM alpine:latest

# Installer les dépendances runtime
RUN apk add --no-cache ca-certificates curl wget postgresql-client tzdata

# Créer un utilisateur non-root
RUN addgroup -g 1001 listmonk && \
    adduser -D -u 1001 -G listmonk listmonk

# Créer les répertoires nécessaires
RUN mkdir -p /listmonk/uploads /listmonk/static /listmonk/i18n /listmonk/scripts /listmonk/demo && \
    chown -R listmonk:listmonk /listmonk

# Copier le binaire depuis le builder
COPY --from=builder /src/listmonk /listmonk/listmonk
COPY --from=builder /src/static /listmonk/static
COPY --from=builder /src/i18n /listmonk/i18n

# Copier les scripts d'initialisation
COPY docker/scripts/ /listmonk/scripts/
RUN chmod +x /listmonk/scripts/*.sh

# Copier les fichiers de démonstration
COPY demo_geo_data.csv /listmonk/demo/
COPY demo_geographic_queries.sql /listmonk/demo/
COPY test_geo_data.csv /listmonk/demo/

# Point d'entrée avec initialisation géographique
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Définir l'utilisateur
USER listmonk

# Définir le répertoire de travail
WORKDIR /listmonk

# Exposer le port
EXPOSE 9000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:9000/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["./listmonk", "--config", "config.toml"]
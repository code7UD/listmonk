#!/bin/bash

# Test rapide de l'image officielle Listmonk

set -e

echo "🧪 Test de l'image officielle Listmonk..."

# Vérifier si Docker est disponible
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé"
    exit 1
fi

# Tester l'image officielle
echo "📥 Téléchargement de l'image officielle..."
docker pull listmonk/listmonk:latest

echo "🔍 Inspection de l'image..."
docker run --rm listmonk/listmonk:latest ./listmonk --help

echo "✅ L'image officielle fonctionne !"

# Tester notre build
echo "🔨 Construction de notre image personnalisée..."
docker build -f Dockerfile.geo.official -t listmonk-geo-test .

echo "🔍 Test de notre image..."
docker run --rm listmonk-geo-test ./listmonk --help

echo "✅ Notre image personnalisée fonctionne !"

echo "🧹 Nettoyage..."
docker rmi listmonk-geo-test

echo "🎉 Test terminé avec succès !"
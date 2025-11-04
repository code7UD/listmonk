#!/bin/bash

# Test de construction complète avec frontend et backend

set -e

echo "🧪 Test de construction complète Listmonk avec extension géographique..."

# Vérifier si Docker est disponible
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé"
    exit 1
fi

echo "🔨 Construction de l'image complète (frontend + backend)..."
echo "⚠️  Cela peut prendre plusieurs minutes..."

# Construire l'image
docker build -f Dockerfile.geo.complete -t listmonk-geo-complete .

echo "🔍 Test de l'image construite..."
docker run --rm listmonk-geo-complete ./listmonk --help

echo "✅ Construction réussie !"

echo "🧹 Nettoyage..."
docker rmi listmonk-geo-complete

echo "🎉 Test terminé avec succès !"
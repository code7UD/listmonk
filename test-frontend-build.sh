#!/bin/bash

# Test spécifique du build frontend

set -e

echo "🧪 Test de construction frontend avec correction ESLint..."

# Vérifier si Docker est disponible
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé"
    exit 1
fi

echo "🔨 Test du stage frontend uniquement..."

# Construire seulement le stage frontend pour tester
docker build --target frontend-builder -f Dockerfile.geo.complete -t listmonk-frontend-test .

echo "✅ Build frontend réussi !"

echo "🧹 Nettoyage..."
docker rmi listmonk-frontend-test

echo "🎉 Test frontend terminé avec succès !"
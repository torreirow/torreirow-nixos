#!/usr/bin/env bash

# Script om PostgreSQL database aan te maken
# Gebruik: sudo ./setup-psql-database.sh

set -e

echo "=== PostgreSQL Database Setup ==="
echo ""

# Vraag om database informatie
read -p "Database naam: " DB_NAME
read -p "Database gebruiker [$DB_NAME]: " DB_USER
DB_USER=${DB_USER:-$DB_NAME}
read -sp "Database wachtwoord: " DB_PASSWORD
echo ""
echo ""

# Controleer of PostgreSQL draait
if ! systemctl is-active --quiet postgresql; then
    echo "Error: PostgreSQL service is niet actief!"
    echo "Start eerst PostgreSQL: sudo systemctl start postgresql"
    exit 1
fi

echo "Database en gebruiker aanmaken..."
echo "Database: $DB_NAME"
echo "Gebruiker: $DB_USER"
echo ""

# Voer alle commando's uit via psql
sudo -u postgres psql <<EOF
-- Maak database aan
CREATE DATABASE $DB_NAME;

-- Maak gebruiker aan met wachtwoord
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';

-- Geef CONNECT rechten op database
GRANT CONNECT ON DATABASE $DB_NAME TO $DB_USER;

-- Geef alle privileges op database
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;

-- Verbind met de database
\c $DB_NAME

-- Geef USAGE rechten op public schema
GRANT USAGE ON SCHEMA public TO $DB_USER;

-- Geef CREATE rechten op public schema
GRANT CREATE ON SCHEMA public TO $DB_USER;

-- Geef alle rechten op public schema
GRANT ALL ON SCHEMA public TO $DB_USER;

-- Stel default privileges in voor toekomstige tabellen
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $DB_USER;

-- Geef rechten op bestaande tabellen
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $DB_USER;

-- Geef rechten op sequences (voor auto-increment)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;

-- Default privileges voor sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT USAGE, SELECT ON SEQUENCES TO $DB_USER;
EOF

echo ""
echo "=== Setup compleet! ==="
echo ""
echo "Database naam: $DB_NAME"
echo "Database user: $DB_USER"
echo ""
echo "Toegekende rechten:"
echo "  - CONNECT op database"
echo "  - USAGE en CREATE op schema public"
echo "  - SELECT, INSERT, UPDATE, DELETE op alle tabellen"
echo "  - USAGE, SELECT op alle sequences"
echo "  - Default privileges voor nieuwe objecten"
echo ""
echo "Connection string:"
echo "postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME"
echo ""

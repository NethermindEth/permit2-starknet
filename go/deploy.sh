#!/bin/bash

# Permit2 Contract Deployment Script
# This script runs the Go deployment program

set -e

echo "🚀 Starting Permit2 deployment..."

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo "❌ Go is not installed. Please install Go 1.21+ first."
    exit 1
fi

# Check if contract files exist
if [ ! -f "../target/dev/permit2_Permit2.contract_class.json" ]; then
    echo "❌ Contract files not found. Please run 'scarb build' first."
    exit 1
fi

if [ ! -f "../target/dev/permit2_Permit2.compiled_contract_class.json" ]; then
    echo "❌ Compiled contract files not found. Please run 'scarb build' first."
    exit 1
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "⚠️  .env file not found. Please copy env.example to .env and configure it."
    echo "   cp env.example .env"
    exit 1
fi

# Install dependencies
echo "📦 Installing Go dependencies..."
go mod tidy

# Run the deployment
echo "🚀 Running deployment..."
go run main.go

echo "✅ Deployment script completed!"

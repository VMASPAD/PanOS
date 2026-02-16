#!/usr/bin/env node

// ================================================================
// PanOS - boot.js EJEMPLOS AVANZADOS
// ================================================================
// Reemplaza el contenido de ~/pan-os/rootfs/boot.js con uno de
// estos ejemplos para diferentes casos de uso.
// ================================================================

// ================================================================
// EJEMPLO 1: Sistema Minimalista (por defecto en el build)
// ================================================================
console.log("🚀 PanOS iniciado!");
console.log(`Memoria: ${Math.round(process.memoryUsage().rss / 1024 / 1024)} MB`);

// Nota: Ejemplos originales de Bun removidos. A continuación un ejemplo
// equivalente usando Node.js nativo (http).
// EJEMPLO: servidor HTTP simple con Node.js
const http = require("http");

const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end("Hola desde PanOS (Node.js)!\n");
});

server.listen(8080, () => {
  console.log("Servidor HTTP Node.js escuchando en http://0.0.0.0:8080");
});

// ================================================================
// EJEMPLO 2: Web Framework Completo (React + SSR)
// ================================================================
/*
  Ejemplo React/SSR removido (Bun específico). Si quieres ejecutar
  React/SSR en PanOS, usa un bundle para Node.js o un servidor compatible
  con Node (por ejemplo Express + react-dom/server).
*/

// ================================================================
// EJEMPLO 3: API REST Completa con Base de Datos
// ================================================================
/*
  Ejemplo API REST removido (Bun/slice). Para una API REST en Node.js,
  considera usar SQLite con 'better-sqlite3' o 'sqlite3' y un servidor
  Express/Koa, y adapta las rutas al entorno Node.
*/

// ================================================================
// EJEMPLO 4: Servidor con WebSockets (Chat en tiempo real)
// ================================================================
/*
  Ejemplo WebSocket eliminado (Bun). Para WebSockets en Node.js,
  utiliza 'ws' o 'uWebSockets.js' y crea un servidor compatible con Node.
*/

// ================================================================
// EJEMPLO 5: Sistema de Archivos (Montar directorios)
// ================================================================
/*
  Ejemplo de file server removido (Bun-specific).
  Para servir archivos en Node.js, usa 'express' o el módulo 'http' y
  'fs.createReadStream' para servir archivos estáticos.
*/

// ================================================================
// EJEMPLO 6: Monitoring & Metrics (Prometheus-compatible)
// ================================================================
/*
  Ejemplo de métricas removido (Bun.serve). Para métricas con Node.js,
  monta un endpoint /metrics usando 'prom-client' o genera texto
  Prometheus manualmente y devuélvelo con 'res.end'.
*/

// ================================================================
// EJEMPLO 7: Compilador / Intérprete (Meta - Code as Data)
// ================================================================
/*
  Ejemplo de intérprete dinámico removido. Para este tipo de capacidades
  en Node.js, valida y sandboxea estrictamente antes de evaluar código.
*/

// ================================================================
// Mantener el process vivo
// ================================================================
setInterval(() => {}, 1000000);

process.on("SIGTERM", () => {
  console.log("\n👋 Apagando...");
  process.exit(0);
});

process.on("SIGINT", () => {
  console.log("\n👋 Apagando...");
  process.exit(0);
});

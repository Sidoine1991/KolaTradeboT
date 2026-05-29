#!/usr/bin/env node
/**
 * XAUUSD 20-min WhatsApp alert system
 * Collects TradingView data via MCP + AI server, sends unified alerts every 20 minutes
 */

const http = require("http");
const fs = require("fs");
const path = require("path");

const AI_SERVER_URL = "http://127.0.0.1:8000";
const PSYCHOBOT_URL = "https://psychobot-1si7.onrender.com/send-message";
const WHATSAPP_PHONE = process.env.WHATSAPP_PHONE || "+2290196911346";
const ALERT_LOG = path.join("D:/Dev/TradBOT", "whatsapp_alerts.log");
const CHECK_INTERVAL = 20 * 60 * 1000; // 20 minutes

class XAUUSDMonitor {
  constructor() {
    this.lastData = {};
    this.running = false;
  }

  async fetchAI(endpoint) {
    return new Promise((resolve) => {
      const url = new URL(AI_SERVER_URL);
      url.pathname = endpoint;

      const client = url.protocol === "https:" ? require("https") : http;

      client.get(url, (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          try {
            resolve(JSON.parse(data));
          } catch {
            resolve({});
          }
        });
      });

      setTimeout(() => resolve({}), 5000);
    });
  }

  async fetchAllData() {
    console.log("[Monitor] Fetching data in parallel...");

    // Run AI server calls in parallel
    const [sessionBias, pendingOrder, reportStatus] = await Promise.all([
      this.fetchAI("/session-bias?symbol=XAUUSD"),
      this.fetchAI("/pending-order?symbol=XAUUSD"),
      this.fetchAI("/tradingagents/report-status?symbol=XAUUSD"),
    ]);

    // TradingView data would be fetched via MCP (not available in Node directly)
    // For now, we'll build the message with available AI data and placeholder TV data

    return {
      sessionBias: sessionBias || {},
      pendingOrder: pendingOrder || {},
      reportStatus: reportStatus || {},
      tradingView: {
        price: "N/A",
        vwap: "N/A",
        bb_lower: "N/A",
        bb_mid: "N/A",
        bb_upper: "N/A",
        supertrend: "N/A",
        rsi: "N/A",
      },
      gom: {
        verdict: "WAIT",
        score_buy: 0,
        score_sell: 0,
        spike_pct: 0,
      },
    };
  }

  buildMessage(data) {
    const now = new Date();
    const timestamp = now.toLocaleTimeString("en-US", {
      timeZone: "UTC",
      hour12: false,
    });
    const dateStr = now.toLocaleDateString("fr-FR", {
      timeZone: "UTC",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    });

    const tv = data.tradingView;
    const gom = data.gom;
    const session = data.sessionBias;
    const pending = data.pendingOrder;
    const report = data.reportStatus;

    const gomEmoji = gom.verdict === "BUY" ? "🟢" : gom.verdict === "SELL" ? "🔴" : "⚪";
    const biasEmoji = session.direction === "UP" ? "🟢" : session.direction === "DOWN" ? "🔴" : "⚪";
    const reportEmoji =
      report.direction === "BUY" ? "🟢" : report.direction === "SELL" ? "🔴" : "⚪";

    return `📊 TradBOT [${timestamp} UTC]

*XAUUSD — Suivi 20min* | ${dateStr} ${timestamp} UTC
━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* $${tv.price}
📍 VWAP : $${tv.vwap}
📊 BB : [${tv.bb_lower} / ${tv.bb_mid} / ${tv.bb_upper}]
⚡ Supertrend : $${tv.supertrend}
━━━━━━━━━━━━━━━━━━━━
${gomEmoji} *Verdict GOM KOLA : ${gom.verdict}*
   BUY=${gom.score_buy}  SELL=${gom.score_sell}  Spike=${gom.spike_pct}%
   RSI=${tv.rsi}
━━━━━━━━━━━━━━━━━━━━
${biasEmoji} *Biais session :* ${session.direction || "NEUTRAL"} ${session.strength || 0}% | ✅ valide ${session.valid_duration_hours || 0}h
━━━━━━━━━━━━━━━━━━━━
📦 *Ordre EA :* ${pending.active ? "✅ ACTIF" : "📭 Aucun"}
━━━━━━━━━━━━━━━━━━━━
${reportEmoji} *Rapport TradingAgents :* ${report.direction || "WAIT"} ${report.strength || 0}% | Age: ${report.age_minutes || 0}min | Expire: ${report.expires_in_minutes || 0}min
━━━━━━━━━━━━━━━━━━━━
🎯 *Décision :* ${gom.verdict} (confluence analysée)
━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_`;
  }

  async sendWhatsApp(message) {
    return new Promise((resolve) => {
      const payload = JSON.stringify({
        phone: WHATSAPP_PHONE,
        message: message,
      });

      const url = new URL(PSYCHOBOT_URL);
      const client = url.protocol === "https:" ? require("https") : http;

      const options = {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(payload),
        },
      };

      const req = client.request(url, options, (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          console.log("[WhatsApp] Message sent successfully");
          resolve(true);
        });
      });

      req.on("error", (e) => {
        console.error(`[WhatsApp Error] ${e.message}`);
        resolve(false);
      });

      req.write(payload);
      req.end();

      setTimeout(() => resolve(false), 10000); // 10s timeout
    });
  }

  logAlert(message) {
    const timestamp = new Date().toISOString();
    fs.appendFileSync(ALERT_LOG, `${timestamp} | ${message.substring(0, 100)}...\n`);
  }

  async sendFallback(message) {
    this.logAlert(message);
    console.log("[WhatsApp Fallback] Alert written to log file");
  }

  async run() {
    if (this.running) {
      console.log("[Monitor] Already running");
      return;
    }

    this.running = true;
    console.log("[Monitor] XAUUSD 20-min surveillance started");

    const loop = async () => {
      try {
        const data = await this.fetchAllData();
        const message = this.buildMessage(data);

        console.log("\n" + "=".repeat(50));
        console.log(message);
        console.log("=".repeat(50) + "\n");

        const success = await this.sendWhatsApp(message);

        if (!success) {
          await this.sendFallback(message);
        }
      } catch (e) {
        console.error(`[Error] ${e.message}`);
      }

      if (this.running) {
        setTimeout(loop, CHECK_INTERVAL);
      }
    };

    // Run first check immediately, then every 20 minutes
    await loop();
  }

  stop() {
    this.running = false;
    console.log("[Monitor] Stopped");
  }
}

// Main
const monitor = new XAUUSDMonitor();

if (require.main === module) {
  monitor.run().catch(console.error);

  process.on("SIGINT", () => {
    monitor.stop();
    process.exit(0);
  });
}

module.exports = XAUUSDMonitor;

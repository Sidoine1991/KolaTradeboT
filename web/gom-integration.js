/**
 * GOM KOLA SIDO — moteur client (port simplifié du Pine Script)
 * Zones de confluence, verdict BUY/SELL, alertes pré-spike.
 */
(function (global) {
  'use strict';

  const GOM_CFG = {
    kolaLb: 3,
    kolaBars: 120,
    kolaTouchZonePct: 30,
    obLookback: 10,
    fibLb: 50,
    spikeLb: 25,
    spikeMin: 0.62,
    spikeBlink: 0.52,
    verdictGapTh: 0.45,
    verdictCoherence: true,
    pollMs: 8000,
    aiServer: 'http://127.0.0.1:8000'
  };

  const gomState = {
    local: null,
    external: null,
    externalRaw: null,
    mtfRows: [],
    setup: null,
    zones: {},
    confluenceHits: [],
    inConfluence: false,
    inPreSpikeZone: false,
    lastConfluenceAlert: 0,
    lastPoll: 0,
    priceLines: []
  };

  // Timeframes cibles en secondes — les bougies de base sont agrégées pour former
  // de vraies bougies OHLC à chaque TF avant tout calcul technique.
  const MTF_TARGETS = [
    { label: 'M5',  secs: 300   },
    { label: 'M15', secs: 900   },
    { label: 'H1',  secs: 3600  },
    { label: 'H4',  secs: 14400 },
    { label: 'D1',  secs: 86400 }
  ];

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

  function atrFromCandles(candles, period = 14) {
    if (!candles || candles.length < period + 2) return null;
    const trs = [];
    for (let i = candles.length - period; i < candles.length; i++) {
      const c = candles[i];
      const p = candles[i - 1];
      const tr = Math.max(c.high - c.low, Math.abs(c.high - p.close), Math.abs(c.low - p.close));
      trs.push(tr);
    }
    return trs.reduce((a, b) => a + b, 0) / trs.length;
  }

  function isPivotHigh(candles, i, lb) {
    const h = candles[i].high;
    for (let k = 1; k <= lb; k++) {
      if (i - k < 0 || i + k >= candles.length) return false;
      if (candles[i - k].high >= h || candles[i + k].high > h) return false;
    }
    return true;
  }

  function isPivotLow(candles, i, lb) {
    const l = candles[i].low;
    for (let k = 1; k <= lb; k++) {
      if (i - k < 0 || i + k >= candles.length) return false;
      if (candles[i - k].low <= l || candles[i + k].low < l) return false;
    }
    return true;
  }

  function calcTouches(candles, level, zone, maxBars) {
    let t = 0;
    const n = Math.min(maxBars, candles.length);
    for (let i = candles.length - n; i < candles.length; i++) {
      const c = candles[i];
      if (Math.abs(c.high - level) <= zone || Math.abs(c.low - level) <= zone ||
          (c.low <= level && c.high >= level)) t++;
    }
    return t;
  }

  function computeKola(candles, close, atr) {
    const lb = GOM_CFG.kolaLb;
    const touchZone = atr * (GOM_CFG.kolaTouchZonePct / 100);
    // Search the last kolaBars candles only (most recent levels are relevant)
    const slice = candles.slice(-GOM_CFG.kolaBars);
    const maxIdx = slice.length - lb - 1;
    let bestBuy = 0, bestSell = 0, bestBuyT = 0, bestSellT = 0;

    for (let i = lb + 1; i < maxIdx; i++) {
      if (isPivotLow(slice, i, lb)) {
        const lvl = slice[i].low;
        const t = calcTouches(slice, lvl, touchZone, 150);
        if (lvl < close && (t > bestBuyT || (t === bestBuyT && lvl > bestBuy))) {
          bestBuy = lvl;
          bestBuyT = t;
        }
      }
      if (isPivotHigh(slice, i, lb)) {
        const lvl = slice[i].high;
        const t = calcTouches(slice, lvl, touchZone, 150);
        if (lvl > close && (t > bestSellT || (t === bestSellT && (bestSell === 0 || lvl < bestSell)))) {
          bestSell = lvl;
          bestSellT = t;
        }
      }
    }
    return {
      buy: bestBuy > 0 ? bestBuy : null,
      sell: bestSell > 0 ? bestSell : null,
      buyTouches: bestBuyT,
      sellTouches: bestSellT
    };
  }

  function computeFibOTE(candles) {
    const slice = candles.slice(-GOM_CFG.fibLb);
    if (slice.length < 10) return null;
    const high = Math.max(...slice.map(c => c.high));
    const low = Math.min(...slice.map(c => c.low));
    const rng = high - low;
    if (rng <= 0) return null;
    return {
      f618: high - 0.618 * rng,
      f786: high - 0.786 * rng,
      f500: high - 0.5 * rng,
      high,
      low
    };
  }

  function computeOB(candles) {
    const lb = GOM_CFG.obLookback;
    if (candles.length < lb * 2 + 5) return { bull: null, bear: null };
    let obBull = null, obBear = null;
    for (let i = lb + 1; i < candles.length - lb - 1; i++) {
      if (isPivotHigh(candles, i, lb)) {
        const idx = i;
        obBear = {
          top: candles[idx].high,
          bot: Math.min(candles[idx].open, candles[idx].close),
          bar: idx
        };
      }
      if (isPivotLow(candles, i, lb)) {
        const idx = i;
        obBull = {
          top: Math.max(candles[idx].open, candles[idx].close),
          bot: candles[idx].low,
          bar: idx
        };
      }
    }
    const close = candles[candles.length - 1].close;
    // Invalidate OB only when price has fully crossed through it (mitigated)
    if (obBear && close > obBear.top) obBear = null;
    if (obBull && close < obBull.bot) obBull = null;
    return { bull: obBull, bear: obBear };
  }

  function ema(vals, period) {
    const k = 2 / (period + 1);
    let e = vals[0];
    for (let i = 1; i < vals.length; i++) e = vals[i] * k + e * (1 - k);
    return e;
  }

  function computeRSI(closes, period = 14) {
    if (closes.length < period + 2) return 50;
    let gains = 0, losses = 0;
    for (let i = closes.length - period; i < closes.length; i++) {
      const d = closes[i] - closes[i - 1];
      if (d >= 0) gains += d;
      else losses -= d;
    }
    const avgG = gains / period;
    const avgL = losses / period;
    if (avgL <= 0) return 100;
    const rs = avgG / avgL;
    return 100 - 100 / (1 + rs);
  }

  // Agrège des bougies de granularity `baseSecs` en bougies de `targetSecs`.
  // Chaque bougie synthétique regroupe floor(targetSecs/baseSecs) bougies source.
  function aggregateCandles(candles, baseSecs, targetSecs) {
    const ratio = Math.round(targetSecs / baseSecs);
    if (ratio <= 1) return candles.slice();
    const out = [];
    for (let i = 0; i + ratio <= candles.length; i += ratio) {
      const slice = candles.slice(i, i + ratio);
      out.push({
        time:  slice[0].time,
        epoch: slice[0].epoch ?? slice[0].time,
        open:  slice[0].open,
        high:  Math.max(...slice.map(c => c.high)),
        low:   Math.min(...slice.map(c => c.low)),
        close: slice[slice.length - 1].close
      });
    }
    return out;
  }

  // Détecte la structure de marché (HH/HL = haussier, LH/LL = baissier).
  // Cherche les 3 derniers pivots significatifs et vérifie la séquence.
  function marketStructure(candles) {
    if (candles.length < 6) return 0;
    const lb = Math.max(2, Math.floor(candles.length / 8));
    const pivotHighs = [], pivotLows = [];
    for (let i = lb; i < candles.length - lb; i++) {
      const h = candles[i].high;
      const l = candles[i].low;
      let isPH = true, isPL = true;
      for (let k = 1; k <= lb; k++) {
        if (candles[i - k].high >= h || candles[i + k].high >= h) isPH = false;
        if (candles[i - k].low  <= l || candles[i + k].low  <= l) isPL = false;
      }
      if (isPH) pivotHighs.push(h);
      if (isPL) pivotLows.push(l);
    }
    if (pivotHighs.length < 2 || pivotLows.length < 2) return 0;
    const lastH  = pivotHighs[pivotHighs.length - 1];
    const prevH  = pivotHighs[pivotHighs.length - 2];
    const lastL  = pivotLows[pivotLows.length - 1];
    const prevL  = pivotLows[pivotLows.length - 2];
    const hhhl = lastH > prevH && lastL > prevL;   // Higher High + Higher Low → BULL
    const lhll = lastH < prevH && lastL < prevL;   // Lower High + Lower Low  → BEAR
    if (hhhl) return 1;
    if (lhll) return -1;
    return 0;
  }

  // Analyse technique complète sur un jeu de bougies agrégées.
  // Retourne dir (-1/0/1) + rsi + score de confiance.
  function mtfDirFromAggregated(candles) {
    if (!candles || candles.length < 5) return { dir: 0, rsi: 50, conf: 0 };
    const closes = candles.map(c => c.close);
    const n = closes.length;
    const c = closes[n - 1];
    const rsi = computeRSI(closes, Math.min(14, n - 1));

    // EMA — on adapte les périodes au nombre de bougies disponibles
    const fast  = Math.min(9,  Math.floor(n * 0.35));
    const slow  = Math.min(21, Math.floor(n * 0.7));
    const trend = Math.min(50, n - 1);
    const emFast  = n > fast  ? ema(closes, fast)  : null;
    const emSlow  = n > slow  ? ema(closes, slow)  : null;
    const emTrend = n > trend ? ema(closes, trend) : null;

    // Structure de marché
    const ms = marketStructure(candles);

    // Momentum : direction des N dernières clôtures
    const momPeriod = Math.min(5, Math.floor(n / 3));
    const momBull = c > closes[n - 1 - momPeriod];
    const momBear = c < closes[n - 1 - momPeriod];

    // Pente EMA lente sur les 3 dernières valeurs
    let emaSlopeBull = false, emaSlopeBear = false;
    if (emSlow != null && n > slow + 2) {
      const emSlowPrev = ema(closes.slice(0, -2), slow);
      emaSlopeBull = emSlow > emSlowPrev;
      emaSlopeBear = emSlow < emSlowPrev;
    }

    // Score pondéré — chaque critère a un poids différent selon sa fiabilité
    let score = 0;
    if (emFast != null && emSlow != null) score += emFast > emSlow ? 2 : -2;   // croisement EMA : fort
    if (emTrend != null)                  score += c > emTrend    ? 1 : -1;   // prix vs tendance longue
    if (ms !== 0)                         score += ms * 2;                    // structure HH/HL ou LH/LL : fort
    score += rsi > 55 ? 1 : rsi < 45 ? -1 : 0;                               // RSI zone
    score += rsi > 65 ? 1 : rsi < 35 ? -1 : 0;                               // RSI extrême bonus
    score += momBull  ? 0.5 : momBear ? -0.5 : 0;                            // momentum court terme
    score += emaSlopeBull ? 0.5 : emaSlopeBear ? -0.5 : 0;                   // pente EMA

    // Seuil : score absolu ≥ 3.5 pour affirmer une direction
    const dir = score >= 3.5 ? 1 : score <= -3.5 ? -1 : 0;

    // Confiance 0-100 : proportion du score max atteint
    const maxScore = 8;
    const conf = Math.round(Math.min(Math.abs(score) / maxScore, 1) * 100);

    return { dir, rsi: Math.round(rsi), conf };
  }

  function computeMTFRows(candles) {
    const baseSecs = global.chartState?.granularity || 120;
    const rows = [];

    for (const tgt of MTF_TARGETS) {
      // Ignorer les TF inférieurs ou égaux au granularity de base
      if (tgt.secs <= baseSecs) continue;
      const agg = aggregateCandles(candles, baseSecs, tgt.secs);
      // Minimum 10 bougies agrégées pour un signal fiable
      if (agg.length < 10) continue;
      const { dir, rsi, conf } = mtfDirFromAggregated(agg);
      rows.push({ tf: tgt.label, dir, rsi, conf });
    }

    // Si aucun TF supérieur n'est disponible, analyser le TF courant directement
    if (rows.length === 0 && candles.length >= 10) {
      const { dir, rsi, conf } = mtfDirFromAggregated(candles.slice(-Math.min(candles.length, 100)));
      const label = baseSecs <= 60 ? 'M1' : baseSecs <= 300 ? 'M5' : baseSecs <= 900 ? 'M15' : 'H1';
      rows.push({ tf: label, dir, rsi, conf });
    }

    let tb = 0, ts = 0;
    for (const r of rows) {
      if (r.dir === 1) tb++;
      else if (r.dir === -1) ts++;
    }
    // Global : majorité stricte requise (plus de la moitié des TF alignés)
    const total = rows.length;
    const gd = tb > total / 2 ? 1 : ts > total / 2 ? -1 : 0;
    return { rows, tb, ts, gd };
  }

  function computeSetup(candles, g, ob, atr) {
    const empty = {
      type: '—', confirm: '—', entry: null, sl: null, tp1: null, tp2: null, rr: null, dir: 0
    };
    if (!candles?.length || !g) return empty;
    const last = candles[candles.length - 1];
    const rng = last.high - last.low;
    if (rng <= 0) return empty;
    const body = Math.abs(last.close - last.open);
    const lw = Math.min(last.open, last.close) - last.low;
    const up = last.high - Math.max(last.open, last.close);
    const pinBull = lw / rng >= 0.52 && body / rng <= 0.38 && last.close > last.open;
    const pinBear = up / rng >= 0.52 && body / rng <= 0.38 && last.close < last.open;
    const gap = g.verdict_gap ?? Math.abs((g.buy_score || 0) - (g.sell_score || 0));

    if (ob.bull && (g.buy_score || 0) >= (g.sell_score || 0) && gap >= 0.8) {
      const entry = ob.bull.top;
      const sl = ob.bull.bot - atr * 0.12;
      const risk = entry - sl;
      if (risk > 0) {
        return {
          type: 'OB_BULL',
          confirm: pinBull ? 'PIN_BAR_BULL' : '—',
          entry,
          sl,
          tp1: entry + risk,
          tp2: entry + risk * 1.5,
          rr: 1,
          dir: 1
        };
      }
    }
    if (ob.bear && (g.sell_score || 0) > (g.buy_score || 0) && gap >= 0.8) {
      const entry = ob.bear.bot;
      const sl = ob.bear.top + atr * 0.12;
      const risk = sl - entry;
      if (risk > 0) {
        return {
          type: 'OB_BEAR',
          confirm: pinBear ? 'PIN_BAR_BEAR' : '—',
          entry,
          sl,
          tp1: entry - risk,
          tp2: entry - risk * 1.5,
          rr: 1,
          dir: -1
        };
      }
    }
    return empty;
  }

  function dirLabel(d) {
    return d === 1 ? 'BULL' : d === -1 ? 'BEAR' : 'NEUT';
  }

  function dirCellClass(d) {
    return d === 1 ? 'gom-cell-bull' : d === -1 ? 'gom-cell-bear' : 'gom-cell-neut';
  }

  function fmtPrice(p) {
    if (p == null || !Number.isFinite(p)) return '—';
    return p >= 1000 ? p.toFixed(2) : p >= 10 ? p.toFixed(3) : p.toFixed(5);
  }

  function computeSupertrend(candles, mult = 3, atrPer = 10) {
    const closes = candles.map(c => c.close);
    const atr = atrFromCandles(candles, atrPer) || 0.001;
    const last = candles[candles.length - 1];
    const hl2 = (last.high + last.low) / 2;
    const up = hl2 - mult * atr;
    const dn = hl2 + mult * atr;
    const stDir = last.close > dn ? 1 : last.close < up ? -1 : 1;
    const stLine = stDir === 1 ? up : dn;
    return { stDir, stLine, atr };
  }

  function computeSpikeScore(candles, stDir, vwap, bbMid, bbWidth, bbSqueeze) {
    const lb = GOM_CFG.spikeLb;
    if (candles.length < lb + 5) return { prob: 0, bull: false, bear: false };
    const last = candles[candles.length - 1];
    const prev = candles[candles.length - 2];
    const atr = atrFromCandles(candles, 14) || 0.001;
    const atrPrev = atrFromCandles(candles.slice(0, -1), 14) || atr;
    const atrComp = atrPrev > 0 && atr / atrPrev < 1 ? clamp((1 - atr / atrPrev) / 0.6, 0, 1) : 0;
    const ch1 = prev.close ? (last.close - prev.close) / prev.close : 0;
    const ch2 = candles[candles.length - 4]?.close
      ? (candles[candles.length - 3].close - candles[candles.length - 4].close) / candles[candles.length - 4].close
      : 0;
    const accel = clamp(Math.abs(ch1 - ch2) / 0.003, 0, 1);
    const ranges = candles.slice(-lb).map(c => c.high - c.low);
    const avgR = ranges.reduce((a, b) => a + b, 0) / ranges.length;
    const body = Math.abs(last.close - last.open);
    const bodyRatio = (last.high - last.low) > 0 ? body / (last.high - last.low) : 0;
    const spikeMql = 0.4 * atrComp + 0.35 * accel + 0.25 * 0;
    const momentum = Math.abs(last.close - candles[candles.length - lb].close) / (avgR * lb + 0.0001);
    const bodyScore = bodyRatio > 0.65 ? 0.4 : bodyRatio > 0.45 ? 0.2 : 0;
    const stScore = ((last.close > stDir.stLine && stDir.stDir === 1) ||
      (last.close < stDir.stLine && stDir.stDir === -1)) ? 0.3 : -0.1;
    const bbSq = bbSqueeze ? 0.3 : 0;
    const raw = momentum * 0.25 + spikeMql * 0.4 + bodyScore * 0.15 + bbSq * 0.1 + stScore * 0.1;
    const prob = clamp(raw, 0, 1);
    const bull = last.close > last.open && last.close > vwap && stDir.stDir === 1;
    const bear = last.close < last.open && last.close < vwap && stDir.stDir === -1;
    return { prob, bull, bear };
  }

  function computeGOMFromCandles(candles) {
    if (!candles || candles.length < 60) return null;
    const close = candles[candles.length - 1].close;
    const atr = atrFromCandles(candles, 14) || 0.001;
    const kola = computeKola(candles, close, atr);
    const fib = computeFibOTE(candles);
    const ob = computeOB(candles);
    const st = computeSupertrend(candles);

    const closes = candles.map(c => c.close);
    const vwap = closes.slice(-30).reduce((a, b) => a + b, 0) / Math.min(30, closes.length);
    const bbSlice = closes.slice(-20);
    const bbMid = bbSlice.reduce((a, b) => a + b, 0) / bbSlice.length;
    const variance = bbSlice.reduce((s, x) => s + (x - bbMid) ** 2, 0) / bbSlice.length;
    const bbStd = Math.sqrt(variance);
    const bbUp = bbMid + 2 * bbStd;
    const bbDn = bbMid - 2 * bbStd;
    const bbWidth = bbUp - bbDn;
    const bbPctb = bbWidth > 0 ? (close - bbDn) / bbWidth : 0.5;
    const bbSqueeze = bbWidth < bbMid * 0.002;

    const spike = computeSpikeScore(candles, st, vwap, bbMid, bbWidth, bbSqueeze);

    let scoreBuy = 0, scoreSell = 0;
    scoreBuy += st.stDir === 1 ? 1.5 : 0;
    scoreSell += st.stDir === -1 ? 1.5 : 0;
    scoreBuy += close > vwap ? 1 : 0;
    scoreSell += close < vwap ? 1 : 0;
    scoreBuy += close > bbMid ? 0.5 : 0;
    scoreSell += close < bbMid ? 0.5 : 0;
    if (ob.bull && close >= ob.bull.bot && close <= ob.bull.top * 1.003) scoreBuy += 1.5;
    if (ob.bear && close <= ob.bear.top && close >= ob.bear.bot * 0.997) scoreSell += 1.5;
    if (spike.prob >= GOM_CFG.spikeMin && spike.bull) scoreBuy += 2;
    if (spike.prob >= GOM_CFG.spikeMin && spike.bear) scoreSell += 2;

    const kolaNearBuy = kola.buy && Math.abs(close - kola.buy) <= atr * 1.5;
    const kolaNearSell = kola.sell && Math.abs(close - kola.sell) <= atr * 1.5;
    if (kolaNearBuy) scoreBuy += 1.5;
    if (kolaNearSell) scoreSell += 1.5;

    const verdictGap = Math.abs(scoreBuy - scoreSell);
    const filterRatio = 0.55;
    const coherenceOk = !GOM_CFG.verdictCoherence || filterRatio >= 0.4 ||
      verdictGap >= GOM_CFG.verdictGapTh + 0.24;

    let verdictNum = 0, verdictTxt = 'WAIT';
    if (scoreSell > scoreBuy && verdictGap >= 4 && coherenceOk) { verdictNum = -3; verdictTxt = 'PERFECT SELL'; }
    else if (scoreSell > scoreBuy && verdictGap >= 2.5 && coherenceOk) { verdictNum = -2; verdictTxt = 'GOOD SELL'; }
    else if (scoreSell > scoreBuy && verdictGap >= 0.6 && coherenceOk) { verdictNum = -1; verdictTxt = 'SELL'; }
    else if (scoreBuy > scoreSell && verdictGap >= 4 && coherenceOk) { verdictNum = 3; verdictTxt = 'PERFECT BUY'; }
    else if (scoreBuy > scoreSell && verdictGap >= 2.5 && coherenceOk) { verdictNum = 2; verdictTxt = 'GOOD BUY'; }
    else if (scoreBuy > scoreSell && verdictGap >= 0.6 && coherenceOk) { verdictNum = 1; verdictTxt = 'BUY'; }

    const dirEq = scoreBuy > scoreSell ? 'BUY' : scoreSell > scoreBuy ? 'SELL' : 'WAIT';
    let gapN = 0;
    if (dirEq !== 'WAIT' && verdictGap > GOM_CFG.verdictGapTh) {
      gapN = clamp((verdictGap - GOM_CFG.verdictGapTh) / (GOM_CFG.verdictGapTh * 2.5), 0, 1);
    }
    const spikeAligned = (dirEq === 'BUY' && spike.bull) || (dirEq === 'SELL' && spike.bear);
    const spN = spikeAligned ? clamp(spike.prob / 0.72, 0, 1) : spike.prob > 0 ? 0.14 * clamp(spike.prob / 0.55, 0, 1) : 0;
    const lcN = (dirEq === 'BUY' && kolaNearBuy) || (dirEq === 'SELL' && kolaNearSell) ? 0.8 : 0;
    const quality = clamp(0.2 * gapN + 0.3 * spN + 0.24 * lcN + 0.16 * filterRatio + 0.1 * filterRatio, 0, 1);

    gomState.zones = {
      kolaBuy: kola.buy,
      kolaSell: kola.sell,
      oteTop: fib ? Math.max(fib.f618, fib.f786) : null,
      oteBot: fib ? Math.min(fib.f618, fib.f786) : null,
      obBull: ob.bull,
      obBear: ob.bear,
      fib500: fib?.f500 ?? null
    };

    const rsi14 = Math.round(computeRSI(closes, 14));
    const rsiOversold = rsi14 < 28;
    const rsiOverbought = rsi14 > 72;
    const mtf = computeMTFRows(candles);
    gomState.mtfRows = mtf.rows;

    const base = {
      verdict: verdictTxt,
      verdictNum,
      buy_score: Math.round(scoreBuy * 10) / 10,
      sell_score: Math.round(scoreSell * 10) / 10,
      spike_pct: Math.round(spike.prob * 100),
      quality: Math.round(quality * 100),
      coherence: Math.round(filterRatio * 100),
      kola_state: kolaNearBuy ? 'NEAR BUY' : kolaNearSell ? 'NEAR SELL' : '---',
      rsi: rsi14,
      st_direction: st.stDir === 1 ? 'UP' : 'DN',
      verdict_gap: Math.round(verdictGap * 10) / 10,
      atr,
      rsi_oversold: rsiOversold,
      rsi_overbought: rsiOverbought,
      mtf_global: mtf.gd,
      mtf_tb: mtf.tb,
      mtf_ts: mtf.ts,
      kola_buy: kola.buy,
      kola_sell: kola.sell
    };

    gomState.setup = computeSetup(candles, base, ob, atr);
    base.setup = gomState.setup;
    return base;
  }

  function checkConfluence(price, atr) {
    const z = gomState.zones;
    const pad = atr * 0.35;
    const hits = [];
    if (z.oteTop != null && z.oteBot != null) {
      const top = Math.max(z.oteTop, z.oteBot);
      const bot = Math.min(z.oteTop, z.oteBot);
      if (price >= bot - pad && price <= top + pad) hits.push('OTE');
    }
    if (z.kolaBuy && Math.abs(price - z.kolaBuy) <= atr * 1.2) hits.push('KOLA_BUY');
    if (z.kolaSell && Math.abs(price - z.kolaSell) <= atr * 1.2) hits.push('KOLA_SELL');
    if (z.obBull && price >= z.obBull.bot - pad && price <= z.obBull.top + pad) hits.push('OB_BULL');
    if (z.obBear && price >= z.obBear.bot - pad && price <= z.obBear.top + pad) hits.push('OB_BEAR');
    gomState.confluenceHits = hits;
    gomState.inConfluence = hits.length > 0;
    return hits;
  }

  function clearGOMPriceLines() {
    const series = global.chartState?.candleSeries;
    if (!series) return;
    for (const pl of gomState.priceLines) {
      try { series.removePriceLine(pl); } catch (_) { /* ignore */ }
    }
    gomState.priceLines = [];
  }

  function renderGOMZones() {
    if (!document.getElementById('showGomZones')?.checked) {
      clearGOMPriceLines();
      return;
    }
    const series = global.chartState?.candleSeries;
    if (!series) return;
    clearGOMPriceLines();
    const z = gomState.zones;
    const add = (price, color, title, style) => {
      if (price == null || !Number.isFinite(price)) return;
      const line = series.createPriceLine({
        price,
        color,
        lineWidth: 2,
        lineStyle: style || LightweightCharts.LineStyle.Solid,
        axisLabelVisible: true,
        title
      });
      gomState.priceLines.push(line);
    };
    add(z.kolaBuy, '#00ff88', 'KOLA BUY', LightweightCharts.LineStyle.Solid);
    add(z.kolaSell, '#ff4444', 'KOLA SELL', LightweightCharts.LineStyle.Solid);
    add(z.oteTop, '#ff00ff', 'OTE 61.8', LightweightCharts.LineStyle.Dashed);
    add(z.oteBot, '#ff00ff', 'OTE 78.6', LightweightCharts.LineStyle.Dashed);
    add(z.fib500, '#ffaa00', 'Fib 50%', LightweightCharts.LineStyle.Dotted);
    if (z.obBull) {
      add(z.obBull.top, '#00ff8844', 'OB Bull top', LightweightCharts.LineStyle.Solid);
      add(z.obBull.bot, '#00ff8844', 'OB Bull bot', LightweightCharts.LineStyle.Solid);
    }
    if (z.obBear) {
      add(z.obBear.top, '#ff444444', 'OB Bear top', LightweightCharts.LineStyle.Solid);
      add(z.obBear.bot, '#ff444444', 'OB Bear bot', LightweightCharts.LineStyle.Solid);
    }
  }

  function getActiveGOM() {
    if (document.getElementById('gomUseExternal')?.checked && gomState.external) {
      return gomState.external;
    }
    return gomState.local;
  }

  function gomAllowsTrade(direction) {
    if (!document.getElementById('useGOMVerdict')?.checked) return { ok: true, reason: '' };
    const g = getActiveGOM();
    if (!g) return { ok: false, reason: 'GOM: données insuffisantes' };
    const minQ = parseInt(document.getElementById('gomMinQuality')?.value || '30', 10);
    const minV = parseInt(document.getElementById('gomMinVerdict')?.value || '1', 10);
    const vn = g.verdictNum ?? 0;
    const q = g.quality ?? 0;
    if (q < minQ) return { ok: false, reason: `GOM quality ${q}% < ${minQ}%` };
    if (direction === 'buy') {
      if (vn < minV) return { ok: false, reason: `GOM ${g.verdict} (besoin BUY ≥ ${minV})` };
    } else if (direction === 'sell') {
      if (vn > -minV) return { ok: false, reason: `GOM ${g.verdict} (besoin SELL ≤ -${minV})` };
    }
    return { ok: true, reason: g.verdict };
  }

  async function pollExternalGOM() {
    if (!document.getElementById('gomUseExternal')?.checked) return false;
    const now = Date.now();
    if (now - gomState.lastPoll < GOM_CFG.pollMs) return false;
    gomState.lastPoll = now;
    try {
      const r = await fetch(`${GOM_CFG.aiServer}/gom/latest`, { cache: 'no-store' });
      if (!r.ok) return false;
      const data = await r.json();
      if (data && (data.verdict || data.verdict_num != null)) {
        gomState.externalRaw = data;
        gomState.external = {
          verdict: data.verdict,
          verdictNum: data.verdict_num ?? data.verdictNum ?? 0,
          buy_score: data.buy_score ?? data.score_buy,
          sell_score: data.sell_score ?? data.score_sell,
          spike_pct: data.spike_pct,
          quality: data.quality ?? data.entry_quality,
          coherence: data.coherence ?? data.coherence_pct,
          kola_state: data.kola_state,
          rsi: data.rsi,
          st_direction: data.st_direction || (data.st_dir === 1 ? 'UP' : data.st_dir === -1 ? 'DN' : '—'),
          verdict_gap: data.verdict_gap,
          mtf_global: data.tf_global_dir,
          mtf_tb: data.tf_bull_count,
          mtf_ts: data.tf_bear_count,
          pred_bull: data.pred_bull,
          pred_bear: data.pred_bear,
          pred_neut: data.pred_neut,
          pred_net: data.pred_net,
          setup: {
            type: data.setup_type || '—',
            confirm: data.setup_confirm || '—',
            entry: data.setup_entry,
            sl: data.setup_sl,
            tp1: data.setup_tp1,
            tp2: data.setup_tp2,
            rr: data.setup_rr,
            dir: data.setup_dir || 0
          },
          rsi_oversold: data.rsi != null && data.rsi < 28,
          rsi_overbought: data.rsi != null && data.rsi > 72
        };
        return true;
      }
    } catch (_) { /* serveur local optionnel */ }
    return false;
  }

  function getDashboardGOM() {
    const useExt = document.getElementById('gomUseExternal')?.checked && gomState.external;
    const local = gomState.local;
    if (useExt) {
      const e = gomState.external;
      return {
        ...local,
        ...e,
        verdict: e.verdict || local?.verdict,
        verdictNum: e.verdictNum ?? local?.verdictNum ?? 0,
        buy_score: e.buy_score ?? local?.buy_score,
        sell_score: e.sell_score ?? local?.sell_score,
        setup: e.setup?.type && e.setup.type !== '—' ? e.setup : (local?.setup || e.setup),
        _source: 'TradingView'
      };
    }
    return local ? { ...local, _source: 'local' } : null;
  }

  function renderGOMDashboard() {
    const g = getDashboardGOM();
    const useExt = g?._source === 'TradingView';

    const srcEl = document.getElementById('gomDashSource');
    if (srcEl) srcEl.textContent = g?._source || '—';

    const big = document.getElementById('gomDashVerdictBig');
    if (big) {
      if (!g) {
        big.textContent = 'WAIT';
        big.className = 'gom-verdict-big wait';
      } else {
        big.textContent = g.verdict || 'WAIT';
        const vn = g.verdictNum ?? 0;
        big.className = 'gom-verdict-big ' + (vn > 0 ? 'buy' : vn < 0 ? 'sell' : 'wait');
      }
    }

    const setVal = (id, text, color) => {
      const el = document.getElementById(id);
      if (!el) return;
      el.textContent = text;
      if (color) el.style.color = color;
    };

    if (!g) {
      ['gomTvBuy', 'gomTvSell', 'gomTvSpike', 'gomTvRsiSt', 'gomTvGap', 'gomTvCoherence', 'gomTvQuality', 'gomTvKola']
        .forEach(id => setVal(id, '—'));
      return;
    }

    setVal('gomTvBuy', String(g.buy_score ?? '—'), 'var(--green)');
    setVal('gomTvSell', String(g.sell_score ?? '—'), 'var(--red)');
    const spike = g.spike_pct ?? 0;
    setVal('gomTvSpike', spike + '%', spike >= 62 ? 'var(--warn)' : 'var(--muted)');
    let rsiAlert = 'normal';
    if (g.rsi_oversold) rsiAlert = 'SURVENTE!';
    else if (g.rsi_overbought) rsiAlert = 'SURACHAT!';
    setVal('gomTvRsiSt', `${g.rsi ?? '—'} / ${g.st_direction || '—'} · ${rsiAlert}`,
      g.rsi_oversold || g.rsi_overbought ? 'var(--warn)' : 'var(--text)');
    const gap = g.verdict_gap ?? 0;
    setVal('gomTvGap', gap + ' pts', gap >= 4 ? 'var(--warn)' : gap >= 2.5 ? 'var(--green)' : 'var(--muted)');
    const coh = g.coherence ?? 0;
    setVal('gomTvCoherence', coh + '%', coh >= 60 ? 'var(--green)' : coh >= 40 ? 'var(--warn)' : 'var(--red)');
    const q = g.quality ?? 0;
    setVal('gomTvQuality', q + '%', q >= 60 ? 'var(--green)' : q >= 30 ? 'var(--warn)' : 'var(--red)');
    const kola = g.kola_state || '---';
    setVal('gomTvKola', kola, kola.includes('BUY') ? 'var(--green)' : kola.includes('SELL') ? 'var(--red)' : 'var(--muted)');

    const confBanner = document.getElementById('gomDashConfluence');
    if (confBanner) {
      if (gomState.inConfluence) {
        confBanner.textContent = `Zone confluence: ${gomState.confluenceHits.join(' + ')}`;
        confBanner.className = 'gom-conf-banner active';
      } else {
        confBanner.textContent = 'Hors zone confluence';
        confBanner.className = 'gom-conf-banner';
      }
    }

    const mtfBody = document.getElementById('gomMtfBody');
    const mtfGlobal = document.getElementById('gomMtfGlobal');
    const rows = useExt && gomState.externalRaw?.mtf_rows
      ? gomState.externalRaw.mtf_rows
      : gomState.mtfRows;

    if (mtfBody) {
      if (!rows?.length) {
        mtfBody.innerHTML = '<tr><td colspan="4" style="color:var(--muted);text-align:center">En attente de bougies…</td></tr>';
      } else {
        mtfBody.innerHTML = rows.map(r => {
          const cls = dirCellClass(r.dir);
          const confCol = r.conf != null
            ? `<td class="val" style="color:${r.conf >= 70 ? 'var(--green)' : r.conf >= 45 ? 'var(--warn)' : 'var(--muted)'}">${r.conf}%</td>`
            : '<td class="val">—</td>';
          return `<tr class="${cls}"><td>${r.tf}</td><td>${dirLabel(r.dir)}</td><td class="val">${r.rsi}</td>${confCol}</tr>`;
        }).join('');
      }
    }

    if (mtfGlobal) {
      const tb = g.mtf_tb ?? 0;
      const ts = g.mtf_ts ?? 0;
      const gd = typeof g.mtf_global === 'string'
        ? g.mtf_global
        : dirLabel(g.mtf_global ?? 0);
      mtfGlobal.textContent = `${gd} · ${tb}B / ${ts}S`;
      mtfGlobal.style.color = gd === 'BULL' ? 'var(--green)' : gd === 'BEAR' ? 'var(--red)' : 'var(--warn)';
    }

    const setup = g.setup || gomState.setup;
    const stType = document.getElementById('gomSetupType');
    if (stType) {
      stType.textContent = setup?.type || '—';
      stType.style.color = setup?.dir === 1 ? 'var(--green)' : setup?.dir === -1 ? 'var(--red)' : 'var(--muted)';
    }
    setVal('gomSetupConfirm', setup?.confirm || '—',
      setup?.confirm?.includes('PIN') ? 'var(--green)' : 'var(--muted)');
    setVal('gomSetupEntry', fmtPrice(setup?.entry));
    setVal('gomSetupSl', fmtPrice(setup?.sl), 'var(--red)');
    setVal('gomSetupTp1', fmtPrice(setup?.tp1), 'var(--green)');
    setVal('gomSetupTp2', fmtPrice(setup?.tp2), 'var(--accent)');
    setVal('gomSetupRr', setup?.rr != null ? String(setup.rr) : '—', 'var(--warn)');

    const pred = document.getElementById('gomPredPath');
    if (pred) {
      const pb = g.pred_bull ?? gomState.externalRaw?.pred_bull;
      const pbe = g.pred_bear ?? gomState.externalRaw?.pred_bear;
      const pn = g.pred_neut ?? gomState.externalRaw?.pred_neut;
      const pnet = g.pred_net ?? gomState.externalRaw?.pred_net;
      if (pb != null || pbe != null) {
        pred.textContent = `Chemin prédictif: ↑${pb ?? 0} ↓${pbe ?? 0} · neut ${pn ?? 0} · net ${pnet ?? 0}`;
      } else {
        pred.textContent = 'Chemin prédictif: — (activer TV poller)';
      }
    }

    const el = document.getElementById('gomVerdictLabel');
    const sub = document.getElementById('gomVerdictSub');
    if (el && g) {
      el.textContent = g.verdict || 'WAIT';
      const vn = g.verdictNum ?? 0;
      el.className = 'gom-verdict-badge ' + (vn > 0 ? 'buy' : vn < 0 ? 'sell' : 'wait');
      if (sub) {
        sub.textContent = `B:${g.buy_score ?? '—'} S:${g.sell_score ?? '—'} | Spike ${g.spike_pct ?? '—'}% | Q ${g.quality ?? '—'}%`;
      }
    }
    const conf = document.getElementById('gomConfluenceLabel');
    if (conf) {
      conf.textContent = gomState.inConfluence
        ? `Confluence: ${gomState.confluenceHits.join(' + ')}`
        : 'Hors zone confluence';
      conf.style.color = gomState.inConfluence ? 'var(--warn)' : 'var(--muted)';
    }
  }

  function updateGOMUI() {
    renderGOMDashboard();
  }

  function getAllCandles() {
    const cs = global.chartState;
    if (!cs) return null;
    if (cs.forming) return [...cs.candles, cs.forming];
    return cs.candles;
  }

  function refreshGOMFromCandles(price) {
    const candles = getAllCandles();
    const px = price ?? candles?.[candles.length - 1]?.close;
    if (candles && candles.length >= 60) {
      gomState.local = computeGOMFromCandles(candles);
      const atr = gomState.local?.atr || atrFromCandles(candles, 14) || 0.001;
      if (px != null) checkConfluence(px, atr);
      renderGOMZones();
    }
    pollExternalGOM().finally(() => updateGOMUI());
  }

  function updateGOMOnTick(price, spikeAlert) {
    const candles = getAllCandles();
    if (candles && candles.length >= 60) {
      gomState.local = computeGOMFromCandles(candles);
      const atr = gomState.local?.atr || atrFromCandles(candles, 14) || 0.001;
      checkConfluence(price, atr);
      renderGOMZones();
    }
    pollExternalGOM().finally(() => updateGOMUI());

    const useConfAlert = document.getElementById('gomConfluenceAlert')?.checked;
    if (!useConfAlert || !gomState.inConfluence) return;

    const preSpike = spikeAlert && (spikeAlert.level === 'watch' || spikeAlert.level === 'imminent');
    const spikePct = (getActiveGOM()?.spike_pct ?? 0) / 100;
    const preSpikeByScore = spikePct >= GOM_CFG.spikeBlink;

    if ((preSpike || preSpikeByScore) && Date.now() - gomState.lastConfluenceAlert > 9000) {
      gomState.inPreSpikeZone = true;
      gomState.lastConfluenceAlert = Date.now();
      const dir = spikeAlert?.direction || (getActiveGOM()?.verdictNum > 0 ? 'buy' : 'sell');
      if (typeof global.playSpikeBeep === 'function') {
        global.playSpikeBeep(dir, 'imminent');
      }
      if (typeof global.log === 'function') {
        global.log('warn', `ZONE PRÉ-SPIKE GOM [${gomState.confluenceHits.join('+')}] — ${getActiveGOM()?.verdict || ''}`);
      }
    } else {
      gomState.inPreSpikeZone = false;
    }
  }

  global.GOM = {
    state: gomState,
    cfg: GOM_CFG,
    computeGOMFromCandles,
    checkConfluence,
    renderGOMZones,
    renderGOMDashboard,
    getActiveGOM,
    getDashboardGOM,
    gomAllowsTrade,
    refreshGOMFromCandles,
    updateGOMOnTick,
    pollExternalGOM,
    clearGOMPriceLines
  };

  if (typeof document !== 'undefined') {
    document.addEventListener('DOMContentLoaded', () => renderGOMDashboard());
  }
})(typeof window !== 'undefined' ? window : globalThis);

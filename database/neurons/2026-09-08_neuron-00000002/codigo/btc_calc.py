import json, math, random

random.seed(42)

btc_price = 78569.0
high_24h = 81731.0
low_24h = 76591.0
ath = 126080.0
drawdown = ((btc_price - ath) / ath) * 100
daily_vol_pct = 2.7
daily_vol_usd = btc_price * daily_vol_pct / 100
atr_14 = 2100.0
rsi_daily, rsi_weekly = 57.0, 59.0
stoch_k, stoch_d = 45.0, 48.0
adx = 35.0
bb_middle, bb_upper, bb_lower = 78000.0, 83500.0, 72500.0
bb_pct_b = (btc_price - bb_lower) / (bb_upper - bb_lower)
bb_bandwidth = ((bb_upper - bb_lower) / bb_middle) * 100
ema20, ema50, ema100, ema200 = 71500, 68000, 69000, 73000
dist_ema20 = ((btc_price - ema20) / ema20) * 100
dist_ema50 = ((btc_price - ema50) / ema50) * 100
dist_ema100 = ((btc_price - ema100) / ema100) * 100
dist_ema200 = ((btc_price - ema200) / ema200) * 100
oi_total = 54.14e9
oi_change_24h = 1.66
funding = 0.005071
cme_futures = 78820.0
basis_spread = cme_futures - btc_price
basis_pct = (basis_spread / btc_price) * 100
basis_annualized = (basis_pct * 365) / 14
etf_sep_mtd, etf_3week, etf_aum = 770.2, 3800, 99.9e9
fg = 73
sth_cb, tmn, supply_profit = 68500, 75800, 68
score_alcista, score_bajista, score_neutro = 0.30, 0.15, 0.55
alcista_pct = (score_alcista / (score_alcista + score_bajista + score_neutro)) * 100
bajista_pct = (score_bajista / (score_alcista + score_bajista + score_neutro)) * 100
neutro_pct = (score_neutro / (score_alcista + score_bajista + score_neutro)) * 100

n_sim, n_steps, mu, sigma = 10000, 3, 0.0001, daily_vol_pct / 100
sims = []
for _ in range(n_sim):
    path = [btc_price]
    for _ in range(n_steps):
        shock = random.gauss(mu, sigma * math.sqrt(1))
        path.append(path[-1] * (1 + shock))
    sims.append(path)
final_prices = [s[-1] for s in sims]
mc_mean = sum(final_prices) / n_sim
mc_std = math.sqrt(sum((p - mc_mean) ** 2 for p in final_prices) / n_sim)
sorted_prices = sorted(final_prices)
p5, p25, p50, p75, p95 = [
    sorted_prices[int(n_sim * x / 100)] for x in [5, 25, 50, 75, 95]
]
mc_above_82k = sum(1 for p in final_prices if p >= 82000) / n_sim * 100
mc_above_80k = sum(1 for p in final_prices if p >= 80000) / n_sim * 100
mc_below_76k = sum(1 for p in final_prices if p <= 76000) / n_sim * 100
mc_below_74k = sum(1 for p in final_prices if p <= 74000) / n_sim * 100
mc_below_72k = sum(1 for p in final_prices if p <= 72000) / n_sim * 100

inst_24h = (76000 + 80500) / 2
inst_72h = (72000 + 84000) / 2
est_24h, est_72h = btc_price, btc_price
prob_24h = (btc_price + p5 + p95) / 4
prob_72h = mc_mean
pesos = {"institucional": 0.40, "estadistico": 0.30, "probabilistico": 0.30}
final_24h = (
    inst_24h * pesos["institucional"]
    + est_24h * pesos["estadistico"]
    + prob_24h * pesos["probabilistico"]
)
final_72h = (
    inst_72h * pesos["institucional"]
    + est_72h * pesos["estadistico"]
    + prob_72h * pesos["probabilistico"]
)

entry_pb, sl_pb, tp1_pb, tp2_pb, tp3_pb = 76500, 74500, 79730, 82000, 84000
r_pb = entry_pb - sl_pb
r_tp1, r_tp2, r_tp3 = tp1_pb - entry_pb, tp2_pb - entry_pb, tp3_pb - entry_pb
entry_bo, sl_bo, tp1_bo, tp2_bo, tp3_bo = 80500, 78500, 83000, 85000, 88000
r_bo = entry_bo - sl_bo
r_tp1b, r_tp2b, r_tp3b = tp1_bo - entry_bo, tp2_bo - entry_bo, tp3_bo - entry_bo

print("BTC Price:", round(btc_price, 0))
print("Drawdown from ATH:", round(drawdown, 1), "%")
print("24h Range:", int(low_24h), "-", int(high_24h))
print("=" * 50)
print("RSI:", rsi_daily, "/", rsi_weekly)
print("Stoch: %K", stoch_k, "%D", stoch_d)
print("ADX:", adx)
print("BB %B:", round(bb_pct_b, 3), "BW:", round(bb_bandwidth, 1), "%")
print("ATR(14):", atr_14)
print(
    "EMA dist: 20=",
    round(dist_ema20, 1),
    "50=",
    round(dist_ema50, 1),
    "100=",
    round(dist_ema100, 1),
    "200=",
    round(dist_ema200, 1),
)
print("=" * 50)
print("OI:", round(oi_total / 1e9, 2), "B (+", oi_change_24h, "%)")
print("Funding:", round(funding * 100, 4), "%")
print(
    "CME:",
    cme_futures,
    "Basis:",
    round(basis_pct, 2),
    "% (",
    round(basis_annualized, 1),
    "% ann)",
)
print(
    "ETF Sep MTD:",
    etf_sep_mtd,
    "M | 3wk:",
    etf_3week,
    "M | AUM:",
    round(etf_aum / 1e9, 1),
    "B",
)
print("F&G:", fg)
print("=" * 50)
print(
    "Score: Alcista",
    round(alcista_pct, 1),
    "% | Bajista",
    round(bajista_pct, 1),
    "% | Neutro",
    round(neutro_pct, 1),
    "%",
)
print("=" * 50)
print("Monte Carlo 72h: mean", round(mc_mean, 0), "std", round(mc_std, 0))
print("P5:", round(p5, 0), "P50:", round(p50, 0), "P95:", round(p95, 0))
print("Prob >82K:", round(mc_above_82k, 1), "% | >80K:", round(mc_above_80k, 1), "%")
print(
    "Prob <76K:",
    round(mc_below_76k, 1),
    "% | <74K:",
    round(mc_below_74k, 1),
    "% | <72K:",
    round(mc_below_72k, 1),
    "%",
)
print("=" * 50)
print("Proyeccion 24h:", round(final_24h, 0), "| Proyeccion 72h:", round(final_72h, 0))
print("=" * 50)
print("PULLBACK: Entry", entry_pb, "SL", sl_pb, "R=", r_pb)
print("  TP1:", tp1_pb, "R:R", round(r_tp1 / r_pb, 1), ":1, P=60%")
print("  TP2:", tp2_pb, "R:R", round(r_tp2 / r_pb, 1), ":1, P=40%")
print("  TP3:", tp3_pb, "R:R", round(r_tp3 / r_pb, 1), ":1, P=25%")
print("BREAKOUT: Entry", entry_bo, "SL", sl_bo, "R=", r_bo)
print("  TP1:", tp1_bo, "R:R", round(r_tp1b / r_bo, 1), ":1, P=45%")
print("  TP2:", tp2_bo, "R:R", round(r_tp2b / r_bo, 1), ":1, P=30%")
print("  TP3:", tp3_bo, "R:R", round(r_tp3b / r_bo, 1), ":1, P=18%")

resultados = {
    "btc_price": btc_price,
    "drawdown_from_ath": round(drawdown, 1),
    "range_24h": {"low": int(low_24h), "high": int(high_24h)},
    "change_30d_pct": 21.14,
    "rsi": {"daily": rsi_daily, "weekly": rsi_weekly},
    "stochastic": {"k": stoch_k, "d": stoch_d},
    "adx": adx,
    "bollinger": {"pct_b": round(bb_pct_b, 3), "bandwidth": round(bb_bandwidth, 1)},
    "atr_14": atr_14,
    "ema_distances": {
        "ema20": round(dist_ema20, 1),
        "ema50": round(dist_ema50, 1),
        "ema100": round(dist_ema100, 1),
        "ema200": round(dist_ema200, 1),
    },
    "derivatives": {
        "oi_total_b": round(oi_total / 1e9, 2),
        "oi_change_24h": oi_change_24h,
        "funding_pct": round(funding * 100, 4),
        "cme_futures": cme_futures,
        "basis_pct": round(basis_pct, 2),
        "basis_annualized": round(basis_annualized, 1),
    },
    "etf_flows": {
        "sep_mtd_m": etf_sep_mtd,
        "3week_m": etf_3week,
        "aum_b": round(etf_aum / 1e9, 1),
    },
    "fear_greed": fg,
    "on_chain": {"sth_cb": sth_cb, "tmn": tmn, "supply_profit_pct": supply_profit},
    "macro": {
        "fed_rate": "3.50-3.75%",
        "fed_hike_prob": "~50% Kalshi / ~58% CME",
        "ecb_rate": "2.25%",
    },
    "score": {
        "alcista_pct": round(alcista_pct, 1),
        "bajista_pct": round(bajista_pct, 1),
        "neutro_pct": round(neutro_pct, 1),
    },
    "monte_carlo_72h": {
        "mean": round(mc_mean, 0),
        "std": round(mc_std, 0),
        "p5": round(p5, 0),
        "p50": round(p50, 0),
        "p95": round(p95, 0),
        "prob_above_82k": round(mc_above_82k, 1),
        "prob_above_80k": round(mc_above_80k, 1),
        "prob_below_76k": round(mc_below_76k, 1),
        "prob_below_74k": round(mc_below_74k, 1),
        "prob_below_72k": round(mc_below_72k, 1),
    },
    "projections": {"final_24h": round(final_24h, 0), "final_72h": round(final_72h, 0)},
    "levels": {
        "pullback": {
            "entry": entry_pb,
            "sl": sl_pb,
            "tp1": tp1_pb,
            "tp2": tp2_pb,
            "tp3": tp3_pb,
            "r_r_tp1": round(r_tp1 / r_pb, 1),
            "r_r_tp2": round(r_tp2 / r_pb, 1),
            "r_r_tp3": round(r_tp3 / r_pb, 1),
            "prob_tp1": 60,
            "prob_tp2": 40,
            "prob_tp3": 25,
        },
        "breakout": {
            "entry": entry_bo,
            "sl": sl_bo,
            "tp1": tp1_bo,
            "tp2": tp2_bo,
            "tp3": tp3_bo,
            "r_r_tp1": round(r_tp1b / r_bo, 1),
            "r_r_tp2": round(r_tp2b / r_bo, 1),
            "r_r_tp3": round(r_tp3b / r_bo, 1),
            "prob_tp1": 45,
            "prob_tp2": 30,
            "prob_tp3": 18,
        },
    },
}
with open("C:/Users/fazch/AppData/Local/Temp/opencode/btc_results.json", "w") as f:
    json.dump(resultados, f, indent=2)
print("\nJSON guardado exitosamente")

import os
from datetime import datetime
import pandas as pd
import streamlit as st

TRADE_CSV = os.path.join('logs', 'trade_history.csv')

st.set_page_config(page_title="Trade Performance Dashboard", page_icon="📊", layout="wide")

# Auto-refresh léger pour mettre à jour les perfs en continu
st.autorefresh(interval=5000, key="auto_refresh_performance")

st.title("📊 Trade Performance Dashboard")
st.caption("Analyse des performances par symbole, export CSV/Excel, et mise en avant des meilleurs/pires actifs.")

@st.cache_data(show_spinner=False, ttl=5)
def load_trades_csv(path: str) -> pd.DataFrame:
    if not os.path.isfile(path):
        return pd.DataFrame(columns=[
            'timestamp','symbol','type','volume','entry_price','exit_price','open_time','close_time',
            'stop_loss','take_profit','result','confidence','reason','status'
        ])
    df = pd.read_csv(path)
    # Types de base
    for col in ['timestamp','open_time','close_time']:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors='coerce')
    for col in ['volume','entry_price','exit_price','stop_loss','take_profit','result','confidence']:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce')
    if 'symbol' not in df.columns:
        df['symbol'] = ''
    if 'type' not in df.columns:
        df['type'] = ''
    if 'status' not in df.columns:
        df['status'] = ''
    return df

# Bouton d'actualisation manuel qui purge le cache
col_refresh, _ = st.columns([1, 9])
with col_refresh:
    if st.button("🔄 Actualiser", use_container_width=True):
        st.cache_data.clear()

df = load_trades_csv(TRADE_CSV)

col1, col2, col3, col4 = st.columns(4)
total_trades = len(df)
closed_trades = len(df[df['status'].str.upper()=="CLOSED"]) if 'status' in df.columns else total_trades
total_pnl = float(df['result'].sum()) if 'result' in df.columns and not df.empty else 0.0
win_rate = float((df['result']>0).mean()*100) if 'result' in df.columns and total_trades>0 else 0.0

col1.metric("Trades", f"{total_trades}")
col2.metric("Fermés", f"{closed_trades}")
col3.metric("PnL Total", f"{total_pnl:,.2f}")
col4.metric("Win Rate", f"{win_rate:.1f}%")

st.markdown(
    """
    <style>
    .blink { animation: blinker 1.2s linear infinite; }
    @keyframes blinker { 50% { opacity: 0.25; } }
    .float { position: sticky; top: 0; z-index: 999; box-shadow: 0 2px 12px rgba(0,0,0,0.15); }
    </style>
    """,
    unsafe_allow_html=True
)

st.subheader("Classement par symbole")
if df.empty:
    st.info("Aucun trade trouvé. Le fichier logs/trade_history.csv sera alimenté au fur et à mesure des clôtures.")
else:
    group = df.groupby('symbol').agg(
        trades=('symbol','count'),
        pnl=('result','sum'),
        win_rate=(lambda x: (x>0).mean()*100) if 'result' in df.columns else ('result','sum'),
        avg_profit=('result','mean')
    ).reset_index()
    group = group.sort_values('pnl', ascending=False)

    # Meilleur et pire symboles (clignotant)
    best_row = group.iloc[0] if len(group)>0 else None
    worst_row = group.iloc[-1] if len(group)>1 else None

    float_box = st.container()
    with float_box:
        cols = st.columns(2)
        if best_row is not None:
            cols[0].markdown(f"<div class='float'><h3 class='blink'>🏆 Meilleur: {best_row['symbol']}</h3>"
                             f"<p>PnL: <b>{best_row['pnl']:.2f}</b> | Win Rate: <b>{best_row['win_rate']:.1f}%</b> | Trades: <b>{int(best_row['trades'])}</b></p></div>",
                             unsafe_allow_html=True)
        if worst_row is not None:
            cols[1].markdown(f"<div class='float'><h3 class='blink'>⚠️ Pire: {worst_row['symbol']}</h3>"
                             f"<p>PnL: <b>{worst_row['pnl']:.2f}</b> | Win Rate: <b>{worst_row['win_rate']:.1f}%</b> | Trades: <b>{int(worst_row['trades'])}</b></p></div>",
                             unsafe_allow_html=True)

    st.dataframe(group, use_container_width=True)

    st.subheader("Détail des trades")
    st.dataframe(df.sort_values('close_time', ascending=False), use_container_width=True)

    st.subheader("Exports")
    exp_col1, exp_col2 = st.columns(2)
    with exp_col1:
        st.download_button(
            label="⬇️ Export CSV",
            data=df.to_csv(index=False).encode('utf-8'),
            file_name=f"trade_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
            mime="text/csv"
        )
    with exp_col2:
        try:
            xls_bytes = df.to_excel(index=False, sheet_name='Trades')
        except Exception:
            # Fallback via ExcelWriter to bytes
            import io
            output = io.BytesIO()
            with pd.ExcelWriter(output, engine='xlsxwriter') as writer:
                df.to_excel(writer, index=False, sheet_name='Trades')
            xls_bytes = output.getvalue()
        st.download_button(
            label="⬇️ Export Excel",
            data=xls_bytes,
            file_name=f"trade_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx",
            mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )



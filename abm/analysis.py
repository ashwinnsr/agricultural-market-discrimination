# ==============================================================================
# analysis.py
# Post-simulation analysis and visualization for the Agrarian Market ABM
#
# Generates publication-quality figures:
#   1. Price gap dynamics over time (by caste)
#   2. Income divergence trajectories
#   3. Channel share evolution
#   4. Debt trap dynamics
#   5. Scenario comparison (counterfactual analysis)
#   6. Sensitivity analysis plots
#   7. Validation: empirical vs simulated distributions
#
# Usage:
#   python -m abm.analysis
#   (from the code/ directory, after running run_simulation.py)
# ==============================================================================

import os
import sys
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from abm.model import AgrarianMarketModel
from abm import config as C


# ==============================================================================
# STYLE CONFIGURATION
# ==============================================================================

# Colour palette — caste groups
CASTE_COLORS = {
    "General": "#2E86AB",   # steel blue
    "OBC":     "#A23B72",   # muted plum
    "SC":      "#F18F01",   # amber
    "ST":      "#C73E1D",   # terracotta red
}

SCENARIO_COLORS = {
    "baseline":              "#555555",
    "universal_msp":         "#2E86AB",
    "formal_credit":         "#A23B72",
    "fpo_expansion":         "#4CAF50",
    "no_discrimination":     "#F18F01",
    "combined_intervention": "#C73E1D",
}

plt.rcParams.update({
    "font.family": "serif",
    "font.size": 11,
    "axes.titlesize": 13,
    "axes.labelsize": 12,
    "legend.fontsize": 9,
    "figure.dpi": 150,
    "savefig.dpi": 300,
    "savefig.bbox": "tight",
    "axes.spines.top": False,
    "axes.spines.right": False,
})


def ensure_output_dir():
    output_dir = os.path.join(os.path.dirname(__file__), "..", "results", "abm", "figures")
    os.makedirs(output_dir, exist_ok=True)
    return output_dir


# ==============================================================================
# 1. PRICE GAP DYNAMICS
# ==============================================================================

def plot_price_gap_dynamics(ts_data, output_dir, scenario_name="baseline"):
    """Plot price gaps (General vs SC/ST) over time."""
    fig, ax = plt.subplots(figsize=(10, 6))

    seasons = ts_data.index + 1
    ax.plot(seasons, ts_data["Price_Gap_SC_pct"], color=CASTE_COLORS["SC"],
            linewidth=2.5, label="General–SC gap", marker="o", markersize=4)
    ax.plot(seasons, ts_data["Price_Gap_ST_pct"], color=CASTE_COLORS["ST"],
            linewidth=2.5, label="General–ST gap", marker="s", markersize=4)

    ax.axhline(y=0, color="#999999", linestyle="--", linewidth=0.8)
    ax.set_xlabel("Season")
    ax.set_ylabel("Price Gap (%)")
    ax.set_title(f"Caste Price Gap Over Time — {scenario_name.replace('_', ' ').title()}")
    ax.legend(loc="best", framealpha=0.9)
    ax.grid(axis="y", alpha=0.3)

    fig.savefig(os.path.join(output_dir, f"price_gap_dynamics_{scenario_name}.png"))
    plt.close(fig)
    print(f"  ✓ price_gap_dynamics_{scenario_name}.png")


# ==============================================================================
# 2. INCOME TRAJECTORIES BY CASTE
# ==============================================================================

def plot_income_trajectories(ts_data, output_dir, scenario_name="baseline"):
    """Plot mean net income by caste over time."""
    fig, ax = plt.subplots(figsize=(10, 6))

    seasons = ts_data.index + 1
    for caste, color in CASTE_COLORS.items():
        col = f"Income_{caste}"
        if col in ts_data.columns:
            ax.plot(seasons, ts_data[col] / 1000, color=color,
                    linewidth=2.5, label=caste, marker=".", markersize=5)

    ax.set_xlabel("Season")
    ax.set_ylabel("Mean Net Income (₹ thousands)")
    ax.set_title(f"Income Trajectories by Caste — {scenario_name.replace('_', ' ').title()}")
    ax.legend(loc="best", framealpha=0.9)
    ax.grid(axis="y", alpha=0.3)

    fig.savefig(os.path.join(output_dir, f"income_trajectories_{scenario_name}.png"))
    plt.close(fig)
    print(f"  ✓ income_trajectories_{scenario_name}.png")


# ==============================================================================
# 3. WEALTH DIVERGENCE (MPCE)
# ==============================================================================

def plot_wealth_divergence(ts_data, output_dir, scenario_name="baseline"):
    """Plot MPCE (wealth proxy) divergence over time."""
    fig, ax = plt.subplots(figsize=(10, 6))

    seasons = ts_data.index + 1
    for caste, color in CASTE_COLORS.items():
        col = f"MPCE_{caste}"
        if col in ts_data.columns:
            ax.plot(seasons, ts_data[col], color=color,
                    linewidth=2.5, label=caste)

    ax.set_xlabel("Season")
    ax.set_ylabel("Mean MPCE (₹/month)")
    ax.set_title(f"Wealth Divergence (MPCE) — {scenario_name.replace('_', ' ').title()}")
    ax.legend(loc="best", framealpha=0.9)
    ax.grid(axis="y", alpha=0.3)

    fig.savefig(os.path.join(output_dir, f"wealth_divergence_{scenario_name}.png"))
    plt.close(fig)
    print(f"  ✓ wealth_divergence_{scenario_name}.png")


# ==============================================================================
# 4. CHANNEL SHARE EVOLUTION
# ==============================================================================

def plot_channel_evolution(ts_data, output_dir, scenario_name="baseline"):
    """Stacked area chart of SC farmers' channel distribution over time."""
    fig, axes = plt.subplots(1, 2, figsize=(14, 6), sharey=True)

    seasons = ts_data.index + 1
    channel_cols_sc = {
        "SC_Trader_Share": "Local Trader",
        "SC_APMC_Share":   "APMC Mandi",
        "SC_Govt_Share":   "Government",
        "SC_FPO_Share":    "FPO",
    }
    channel_colors = ["#E74C3C", "#2E86AB", "#27AE60", "#F39C12"]

    # SC panel
    ax = axes[0]
    bottom = np.zeros(len(seasons))
    for (col, label), color in zip(channel_cols_sc.items(), channel_colors):
        if col in ts_data.columns:
            vals = ts_data[col].values * 100
            ax.bar(seasons, vals, bottom=bottom, color=color, label=label,
                   width=0.8, alpha=0.85)
            bottom += vals
    ax.set_xlabel("Season")
    ax.set_ylabel("Share (%)")
    ax.set_title("SC Farmers: Channel Distribution")
    ax.legend(loc="upper right", fontsize=8)

    # General panel
    channel_cols_gen = {
        "Gen_Trader_Share": "Local Trader",
        "Gen_APMC_Share":   "APMC Mandi",
    }
    ax = axes[1]
    bottom = np.zeros(len(seasons))
    for (col, label), color in zip(channel_cols_gen.items(), channel_colors[:2]):
        if col in ts_data.columns:
            vals = ts_data[col].values * 100
            ax.bar(seasons, vals, bottom=bottom, color=color, label=label,
                   width=0.8, alpha=0.85)
            bottom += vals
    ax.set_xlabel("Season")
    ax.set_title("General Caste: Channel Distribution")
    ax.legend(loc="upper right", fontsize=8)

    fig.suptitle(f"Market Channel Evolution — {scenario_name.replace('_', ' ').title()}",
                 fontsize=14, y=1.02)
    fig.tight_layout()
    fig.savefig(os.path.join(output_dir, f"channel_evolution_{scenario_name}.png"))
    plt.close(fig)
    print(f"  ✓ channel_evolution_{scenario_name}.png")


# ==============================================================================
# 5. DEBT TRAP DYNAMICS
# ==============================================================================

def plot_debt_dynamics(ts_data, output_dir, scenario_name="baseline"):
    """Plot informal debt rates and distress sale rates over time."""
    fig, axes = plt.subplots(1, 2, figsize=(14, 6))

    seasons = ts_data.index + 1

    # Informal debt rates
    ax = axes[0]
    for caste in ["General", "SC", "ST"]:
        col = f"InformalDebt_{caste[:3]}" if caste != "General" else "InformalDebt_Gen"
        if col in ts_data.columns:
            ax.plot(seasons, ts_data[col] * 100, color=CASTE_COLORS[caste],
                    linewidth=2.5, label=caste)
    ax.set_xlabel("Season")
    ax.set_ylabel("Informal Debt Rate (%)")
    ax.set_title("Informal Debt Prevalence")
    ax.legend(loc="best", framealpha=0.9)
    ax.grid(axis="y", alpha=0.3)

    # Distress sales
    ax = axes[1]
    for caste in ["General", "SC", "ST"]:
        col = f"Distress_{caste[:3]}" if caste != "General" else "Distress_Gen"
        if col in ts_data.columns:
            ax.plot(seasons, ts_data[col] * 100, color=CASTE_COLORS[caste],
                    linewidth=2.5, label=caste)
    ax.set_xlabel("Season")
    ax.set_ylabel("Distress Sale Rate (%)")
    ax.set_title("Distress Sales (Trader + Informal Debt)")
    ax.legend(loc="best", framealpha=0.9)
    ax.grid(axis="y", alpha=0.3)

    fig.suptitle(f"Debt Trap Dynamics — {scenario_name.replace('_', ' ').title()}",
                 fontsize=14, y=1.02)
    fig.tight_layout()
    fig.savefig(os.path.join(output_dir, f"debt_dynamics_{scenario_name}.png"))
    plt.close(fig)
    print(f"  ✓ debt_dynamics_{scenario_name}.png")


# ==============================================================================
# 6. SCENARIO COMPARISON
# ==============================================================================

def plot_scenario_comparison(output_dir):
    """Compare key outcomes across all scenarios."""
    comp_file = os.path.join(output_dir, "..", "scenario_comparison.csv")
    if not os.path.exists(comp_file):
        print("  ⚠ scenario_comparison.csv not found, skipping")
        return

    df = pd.read_csv(comp_file)

    fig, axes = plt.subplots(2, 2, figsize=(14, 10))

    # Price Gap SC
    ax = axes[0, 0]
    colors = [SCENARIO_COLORS.get(s, "#777") for s in df["scenario"]]
    bars = ax.barh(df["scenario_label"], df["price_gap_sc_pct"], color=colors, alpha=0.85)
    ax.set_xlabel("Price Gap: General vs SC (%)")
    ax.set_title("Price Discrimination Against SC")
    ax.axvline(x=0, color="#999", linestyle="--", linewidth=0.8)

    # Income SC
    ax = axes[0, 1]
    bars = ax.barh(df["scenario_label"], df["income_sc"] / 1000, color=colors, alpha=0.85)
    ax.set_xlabel("SC Mean Net Income (₹ thousands)")
    ax.set_title("SC Farm Income")

    # Informal Debt SC
    ax = axes[1, 0]
    bars = ax.barh(df["scenario_label"], df["informal_debt_sc"] * 100, color=colors, alpha=0.85)
    ax.set_xlabel("SC Informal Debt Rate (%)")
    ax.set_title("SC Informal Indebtedness")

    # SC Trader Share
    ax = axes[1, 1]
    bars = ax.barh(df["scenario_label"], df["sc_trader_share"] * 100, color=colors, alpha=0.85)
    ax.set_xlabel("SC Trader Channel Share (%)")
    ax.set_title("SC Dependence on Local Traders")

    fig.suptitle("Policy Counterfactual Comparison", fontsize=15, fontweight="bold", y=1.02)
    fig.tight_layout()
    fig.savefig(os.path.join(output_dir, "scenario_comparison.png"))
    plt.close(fig)
    print(f"  ✓ scenario_comparison.png")


# ==============================================================================
# 7. SENSITIVITY ANALYSIS PLOTS
# ==============================================================================

def plot_sensitivity(output_dir):
    """Plot sensitivity analysis results."""
    fig, axes = plt.subplots(1, 3, figsize=(16, 5))

    # Discrimination factor
    f = os.path.join(output_dir, "..", "sensitivity_discrimination.csv")
    if os.path.exists(f):
        df = pd.read_csv(f)
        ax = axes[0]
        ax.plot(df["param_value"], df["price_gap_sc_pct"], "o-",
                color=CASTE_COLORS["SC"], linewidth=2, label="SC Gap")
        ax.plot(df["param_value"], df["price_gap_st_pct"], "s-",
                color=CASTE_COLORS["ST"], linewidth=2, label="ST Gap")
        ax.set_xlabel("Discrimination Factor")
        ax.set_ylabel("Price Gap (%)")
        ax.set_title("Effect of Discrimination Intensity")
        ax.legend()
        ax.grid(axis="y", alpha=0.3)

    # MSP awareness
    f = os.path.join(output_dir, "..", "sensitivity_msp.csv")
    if os.path.exists(f):
        df = pd.read_csv(f)
        ax = axes[1]
        ax.plot(df["param_value"] * 100, df["price_gap_sc_pct"], "o-",
                color=CASTE_COLORS["SC"], linewidth=2, label="SC Gap")
        ax.plot(df["param_value"] * 100, df["price_gap_st_pct"], "s-",
                color=CASTE_COLORS["ST"], linewidth=2, label="ST Gap")
        ax.set_xlabel("MSP Awareness Boost (%)")
        ax.set_ylabel("Price Gap (%)")
        ax.set_title("Effect of MSP Awareness")
        ax.legend()
        ax.grid(axis="y", alpha=0.3)

    # FPO penetration
    f = os.path.join(output_dir, "..", "sensitivity_fpo.csv")
    if os.path.exists(f):
        df = pd.read_csv(f)
        ax = axes[2]
        ax.plot(df["param_value"] * 100, df["price_gap_sc_pct"], "o-",
                color=CASTE_COLORS["SC"], linewidth=2, label="SC Gap")
        ax.plot(df["param_value"] * 100, df["price_gap_st_pct"], "s-",
                color=CASTE_COLORS["ST"], linewidth=2, label="ST Gap")
        ax.set_xlabel("FPO Penetration Boost (pp)")
        ax.set_ylabel("Price Gap (%)")
        ax.set_title("Effect of FPO Expansion")
        ax.legend()
        ax.grid(axis="y", alpha=0.3)

    fig.suptitle("Sensitivity Analysis", fontsize=14, fontweight="bold", y=1.02)
    fig.tight_layout()
    fig.savefig(os.path.join(output_dir, "sensitivity_analysis.png"))
    plt.close(fig)
    print(f"  ✓ sensitivity_analysis.png")


# ==============================================================================
# 8. VALIDATION FIGURE: Empirical vs Simulated
# ==============================================================================

def plot_validation(output_dir):
    """
    Compare simulated distributions against NSS 77th Round empirical values.
    These are the 'pattern-oriented modelling' validation targets.
    """
    # Empirical targets (from your R analysis)
    empirical = {
        "Trader Share": {
            "General": 0.38, "OBC": 0.42, "SC": 0.52, "ST": 0.55
        },
        "APMC Share": {
            "General": 0.28, "OBC": 0.25, "SC": 0.19, "ST": 0.15
        },
        "Informal Debt Rate": {
            "General": 0.15, "OBC": 0.20, "SC": 0.30, "ST": 0.35
        },
    }

    # Try to load simulated baseline agent data
    agent_file = os.path.join(output_dir, "..", "agents_baseline.csv")
    if not os.path.exists(agent_file):
        print("  ⚠ agents_baseline.csv not found, skipping validation")
        return

    df = pd.read_csv(agent_file)
    df = df[df["Caste"].notna()]

    fig, axes = plt.subplots(1, 3, figsize=(16, 5))

    for i, (metric, emp_vals) in enumerate(empirical.items()):
        ax = axes[i]
        castes = list(emp_vals.keys())
        emp = [emp_vals[c] * 100 for c in castes]

        # Simulated values
        sim = []
        for c in castes:
            sub = df[df["Caste"] == c]
            if metric == "Trader Share":
                sim.append((sub["Channel"] == "LocalTrader").mean() * 100)
            elif metric == "APMC Share":
                sim.append((sub["Channel"] == "APMC").mean() * 100)
            elif metric == "Informal Debt Rate":
                sim.append(sub["InformalDebt"].mean() * 100)

        x = np.arange(len(castes))
        width = 0.35
        bars1 = ax.bar(x - width/2, emp, width, label="NSS 77th (Empirical)",
                       color="#2E86AB", alpha=0.85)
        bars2 = ax.bar(x + width/2, sim, width, label="ABM (Simulated)",
                       color="#F18F01", alpha=0.85)

        ax.set_xticks(x)
        ax.set_xticklabels(castes)
        ax.set_ylabel("%")
        ax.set_title(metric)
        ax.legend(fontsize=8)
        ax.grid(axis="y", alpha=0.3)

    fig.suptitle("Validation: Empirical vs Simulated Distributions",
                 fontsize=14, fontweight="bold", y=1.02)
    fig.tight_layout()
    fig.savefig(os.path.join(output_dir, "validation_comparison.png"))
    plt.close(fig)
    print(f"  ✓ validation_comparison.png")


# ==============================================================================
# MASTER ANALYSIS FUNCTION
# ==============================================================================

def run_analysis():
    """Run all analysis and generate figures."""
    output_dir = ensure_output_dir()
    results_dir = os.path.join(output_dir, "..")

    print("\n" + "=" * 70)
    print("  GENERATING ABM ANALYSIS FIGURES")
    print("=" * 70)

    # Load baseline time series
    ts_file = os.path.join(results_dir, "timeseries_baseline.csv")
    if os.path.exists(ts_file):
        ts_baseline = pd.read_csv(ts_file, index_col=0)
        plot_price_gap_dynamics(ts_baseline, output_dir, "baseline")
        plot_income_trajectories(ts_baseline, output_dir, "baseline")
        plot_wealth_divergence(ts_baseline, output_dir, "baseline")
        plot_channel_evolution(ts_baseline, output_dir, "baseline")
        plot_debt_dynamics(ts_baseline, output_dir, "baseline")
    else:
        print("  ⚠ No baseline time series found. Run simulation first.")

    # Plot counterfactual scenario time series
    for scenario_name in C.SCENARIOS:
        if scenario_name == "baseline":
            continue
        f = os.path.join(results_dir, f"timeseries_{scenario_name}.csv")
        if os.path.exists(f):
            ts = pd.read_csv(f, index_col=0)
            plot_price_gap_dynamics(ts, output_dir, scenario_name)
            plot_income_trajectories(ts, output_dir, scenario_name)

    # Scenario comparison
    plot_scenario_comparison(output_dir)

    # Sensitivity analysis
    plot_sensitivity(output_dir)

    # Validation
    plot_validation(output_dir)

    print(f"\n✅ All figures saved to: {os.path.abspath(output_dir)}")


if __name__ == "__main__":
    run_analysis()

# ==============================================================================
# run_simulation.py
# Main runner for the Agrarian Market ABM
#
# Runs baseline + all counterfactual scenarios, collects results,
# and exports data for analysis.
#
# Usage:
#   python -m abm.run_simulation
#   (from the code/ directory)
# ==============================================================================

import os
import sys
import time
import json
import numpy as np
import pandas as pd
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from abm.model import AgrarianMarketModel
from abm import config as C


def run_single_scenario(scenario_name, num_farmers=C.NUM_FARMERS,
                        num_seasons=C.NUM_SEASONS, seed=C.RANDOM_SEED,
                        verbose=True):
    """
    Run a single scenario and return model + results.
    """
    scenario = C.SCENARIOS.get(scenario_name, C.SCENARIOS["baseline"])

    if verbose:
        print(f"\n{'='*70}")
        print(f"  SCENARIO: {scenario.get('name', scenario_name)}")
        print(f"  Farmers: {num_farmers} | Seasons: {num_seasons} | Seed: {seed}")
        print(f"{'='*70}")

    start = time.time()
    model = AgrarianMarketModel(
        num_farmers=num_farmers,
        scenario_name=scenario_name,
        seed=seed,
    )
    model.run_model(num_seasons=num_seasons)
    elapsed = time.time() - start

    if verbose:
        print(f"  Completed in {elapsed:.1f}s")
        summary = model.get_summary_statistics()
        print(f"\n  --- Final Season Results ---")
        print(f"  Price Gap (Gen vs SC): {summary['price_gap_sc_pct']:.1f}%")
        print(f"  Price Gap (Gen vs ST): {summary['price_gap_st_pct']:.1f}%")
        print(f"  Gini Income:           {summary['gini_income']:.3f}")
        print(f"  SC Trader Share:       {summary['sc_trader_share']:.1%}")
        print(f"  Gen Trader Share:      {summary['gen_trader_share']:.1%}")
        print(f"  Informal Debt SC:      {summary['informal_debt_sc']:.1%}")
        print(f"  Informal Debt Gen:     {summary['informal_debt_gen']:.1%}")
        print(f"  Mean MPCE General:     Rs.{summary['mpce_general']:.0f}")
        print(f"  Mean MPCE SC:          Rs.{summary['mpce_sc']:.0f}")
        print(f"  Mean MPCE ST:          Rs.{summary['mpce_st']:.0f}")

    return model


def run_batch_experiments(num_replications=5, num_farmers=C.NUM_FARMERS,
                          num_seasons=C.NUM_SEASONS, verbose=True):
    """
    Run all scenarios with multiple replications for robustness.
    Returns a DataFrame with summary statistics across replications.
    """
    all_results = []

    for scenario_name in C.SCENARIOS:
        if verbose:
            print(f"\n\n{'#'*70}")
            print(f"  BATCH: {C.SCENARIOS[scenario_name]['name']}")
            print(f"  Replications: {num_replications}")
            print(f"{'#'*70}")

        for rep in range(num_replications):
            seed = C.RANDOM_SEED + rep * 100
            model = AgrarianMarketModel(
                num_farmers=num_farmers,
                scenario_name=scenario_name,
                seed=seed,
            )
            model.run_model(num_seasons=num_seasons)
            summary = model.get_summary_statistics()
            summary["replication"] = rep
            summary["seed"] = seed
            all_results.append(summary)

            if verbose:
                print(f"  Rep {rep+1}/{num_replications}: "
                      f"Gap_SC={summary['price_gap_sc_pct']:.1f}%, "
                      f"Gap_ST={summary['price_gap_st_pct']:.1f}%, "
                      f"Gini={summary['gini_income']:.3f}")

    return pd.DataFrame(all_results)


def run_sensitivity_analysis(param_name, param_values, base_scenario="baseline",
                              num_farmers=C.NUM_FARMERS, num_seasons=C.NUM_SEASONS,
                              verbose=True):
    """
    One-at-a-time sensitivity analysis for a key parameter.
    Varies one parameter while holding others at baseline values.
    """
    results = []

    for val in param_values:
        # Create modified scenario
        scenario = dict(C.SCENARIOS[base_scenario])
        scenario[param_name] = val
        scenario["name"] = f"Sensitivity: {param_name}={val}"

        # Temporarily inject into config
        temp_name = f"_sensitivity_{param_name}_{val}"
        C.SCENARIOS[temp_name] = scenario

        model = AgrarianMarketModel(
            num_farmers=num_farmers,
            scenario_name=temp_name,
            seed=C.RANDOM_SEED,
        )
        model.run_model(num_seasons=num_seasons)
        summary = model.get_summary_statistics()
        summary["param_name"] = param_name
        summary["param_value"] = val
        results.append(summary)

        # Clean up
        del C.SCENARIOS[temp_name]

        if verbose:
            print(f"  {param_name}={val}: Gap_SC={summary['price_gap_sc_pct']:.1f}%, "
                  f"Gini={summary['gini_income']:.3f}")

    return pd.DataFrame(results)


def export_time_series(model, output_dir):
    """Export model-level time series data."""
    model_data = model.datacollector.get_model_dataframe()
    model_data.index.name = "Season"
    model_data.to_csv(os.path.join(output_dir, f"timeseries_{model.scenario_name}.csv"))
    return model_data


def export_agent_data(model, output_dir, season=-1):
    """Export agent-level data for the final season."""
    agent_data = model.datacollector.get_agent_dataframe()
    if not agent_data.empty:
        # Get last step data only
        last_step = agent_data.index.get_level_values("Step").max()
        final = agent_data.xs(last_step, level="Step")
        final = final[final["Caste"].notna()]  # exclude buyer agents
        final.to_csv(os.path.join(output_dir, f"agents_{model.scenario_name}.csv"))
    return agent_data


# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

def main():
    print("=" * 70)
    print("  AGENT-BASED MODEL: Caste Dynamics in Indian Agricultural Markets")
    print("  Calibrated from NSSO 77th Round (2018-19)")
    print("=" * 70)

    # Output directory
    output_dir = os.path.join(os.path.dirname(__file__), "..", "results", "abm")
    os.makedirs(output_dir, exist_ok=True)

    # ─────────────────────────────────────────────────────────
    # 1. BASELINE RUN
    # ─────────────────────────────────────────────────────────
    print("\n\n" + "=" * 70)
    print("  PHASE 1: BASELINE SIMULATION")
    print("=" * 70)

    baseline_model = run_single_scenario("baseline", verbose=True)
    ts_baseline = export_time_series(baseline_model, output_dir)
    export_agent_data(baseline_model, output_dir)

    # ─────────────────────────────────────────────────────────
    # 2. COUNTERFACTUAL SCENARIOS
    # ─────────────────────────────────────────────────────────
    print("\n\n" + "=" * 70)
    print("  PHASE 2: COUNTERFACTUAL SCENARIOS")
    print("=" * 70)

    scenario_models = {"baseline": baseline_model}
    for scenario_name in C.SCENARIOS:
        if scenario_name == "baseline":
            continue
        model = run_single_scenario(scenario_name, verbose=True)
        export_time_series(model, output_dir)
        export_agent_data(model, output_dir)
        scenario_models[scenario_name] = model

    # ─────────────────────────────────────────────────────────
    # 3. BATCH REPLICATIONS (smaller N for speed)
    # ─────────────────────────────────────────────────────────
    print("\n\n" + "=" * 70)
    print("  PHASE 3: BATCH REPLICATIONS (Robustness)")
    print("=" * 70)

    batch_df = run_batch_experiments(
        num_replications=5,
        num_farmers=2000,    # smaller for batch speed
        num_seasons=C.NUM_SEASONS,
        verbose=True,
    )
    batch_df.to_csv(os.path.join(output_dir, "batch_results.csv"), index=False)

    # ─────────────────────────────────────────────────────────
    # 4. SENSITIVITY ANALYSIS
    # ─────────────────────────────────────────────────────────
    print("\n\n" + "=" * 70)
    print("  PHASE 4: SENSITIVITY ANALYSIS")
    print("=" * 70)

    # Vary discrimination intensity
    print("\n--- Discrimination Factor ---")
    sens_disc = run_sensitivity_analysis(
        "discrimination_factor",
        [0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5],
        num_farmers=2000,
        verbose=True,
    )
    sens_disc.to_csv(os.path.join(output_dir, "sensitivity_discrimination.csv"), index=False)

    # Vary MSP awareness boost
    print("\n--- MSP Awareness Boost ---")
    sens_msp = run_sensitivity_analysis(
        "msp_awareness_boost",
        [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        num_farmers=2000,
        verbose=True,
    )
    sens_msp.to_csv(os.path.join(output_dir, "sensitivity_msp.csv"), index=False)

    # Vary FPO penetration
    print("\n--- FPO Penetration Boost ---")
    sens_fpo = run_sensitivity_analysis(
        "fpo_penetration_boost",
        [0.0, 0.05, 0.10, 0.15, 0.20, 0.30, 0.40],
        num_farmers=2000,
        verbose=True,
    )
    sens_fpo.to_csv(os.path.join(output_dir, "sensitivity_fpo.csv"), index=False)

    # ─────────────────────────────────────────────────────────
    # 5. COMPARISON SUMMARY
    # ─────────────────────────────────────────────────────────
    print("\n\n" + "=" * 70)
    print("  PHASE 5: SCENARIO COMPARISON SUMMARY")
    print("=" * 70)

    comparison = []
    for name, model in scenario_models.items():
        comparison.append(model.get_summary_statistics())

    comp_df = pd.DataFrame(comparison)
    comp_df.to_csv(os.path.join(output_dir, "scenario_comparison.csv"), index=False)

    print("\n" + "-" * 90)
    print(f"{'Scenario':<35} {'Gap_SC%':>8} {'Gap_ST%':>8} {'Gini':>6} "
          f"{'SC_Trader':>10} {'InfDebt_SC':>11}")
    print("-" * 90)
    for _, row in comp_df.iterrows():
        print(f"{row['scenario_label']:<35} {row['price_gap_sc_pct']:>8.1f} "
              f"{row['price_gap_st_pct']:>8.1f} {row['gini_income']:>6.3f} "
              f"{row['sc_trader_share']:>10.1%} {row['informal_debt_sc']:>11.1%}")
    print("-" * 90)

    print(f"\n✅ All results saved to: {os.path.abspath(output_dir)}")
    print(f"   Files: {', '.join(os.listdir(output_dir))}")

    return scenario_models, batch_df


if __name__ == "__main__":
    main()

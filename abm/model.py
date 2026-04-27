# ==============================================================================
# model.py
# AgrarianMarketModel — the Mesa model class
#
# Simulates caste-stratified agricultural market dynamics in India.
# Each time step = one agricultural season (Kharif or Rabi).
#
# The model initialises a population of FarmerAgents from NSS 77th Round
# empirical distributions and runs them through seasonal production-marketing
# cycles, collecting data for analysis.
# ==============================================================================

import numpy as np
from mesa import Model
from mesa.datacollection import DataCollector
from .agents import FarmerAgent, BuyerAgent
from . import config as C


# ==============================================================================
# DATA COLLECTOR FUNCTIONS
# ==============================================================================

def get_mean_price_by_caste(model, caste):
    """Weighted mean price received by a specific caste group."""
    farmers = [a for a in model.agents if isinstance(a, FarmerAgent)
               and a.caste == caste and a.price_received > 0]
    if not farmers:
        return 0.0
    return np.mean([f.price_received for f in farmers])


def get_mean_income_by_caste(model, caste):
    """Mean net income by caste."""
    farmers = [a for a in model.agents if isinstance(a, FarmerAgent)
               and a.caste == caste and a.qty_sold > 0]
    if not farmers:
        return 0.0
    return np.mean([f.net_income for f in farmers])


def get_channel_share(model, caste, channel):
    """Share of farmers in a caste group using a specific channel."""
    farmers = [a for a in model.agents if isinstance(a, FarmerAgent)
               and a.caste == caste and a.channel_chosen is not None]
    if not farmers:
        return 0.0
    return sum(1 for f in farmers if f.channel_chosen == channel) / len(farmers)


def get_informal_debt_rate(model, caste):
    """Share of farmers with informal debt."""
    farmers = [a for a in model.agents if isinstance(a, FarmerAgent)
               and a.caste == caste]
    if not farmers:
        return 0.0
    return sum(1 for f in farmers if f.has_informal_debt) / len(farmers)


def get_gini_income(model):
    """Gini coefficient of net incomes across all active farmers."""
    incomes = [f.net_income for f in model.agents
               if isinstance(f, FarmerAgent) and f.qty_sold > 0]
    if len(incomes) < 2:
        return 0.0
    incomes = sorted(incomes)
    n = len(incomes)
    # Shift incomes to non-negative for Gini calculation
    min_inc = min(incomes)
    if min_inc < 0:
        incomes = [x - min_inc + 1 for x in incomes]
    total = sum(incomes)
    if total == 0:
        return 0.0
    cumulative = np.cumsum(incomes)
    gini = (2 * np.sum((np.arange(1, n + 1) * np.array(incomes)))) / (n * total) - (n + 1) / n
    return max(0, min(1, gini))


def get_mean_mpce(model, caste):
    """Mean MPCE (wealth proxy) by caste."""
    farmers = [a for a in model.agents if isinstance(a, FarmerAgent)
               and a.caste == caste]
    if not farmers:
        return 0.0
    return np.mean([f.mpce for f in farmers])


def get_distress_sale_rate(model, caste):
    """Share of farmers selling to trader while having informal debt."""
    farmers = [a for a in model.agents if isinstance(a, FarmerAgent)
               and a.caste == caste and a.channel_chosen is not None]
    if not farmers:
        return 0.0
    return sum(1 for f in farmers
               if f.has_informal_debt and f.channel_chosen == "LocalTrader") / len(farmers)


def get_price_gap_sc(model):
    """Raw price gap: General mean price - SC mean price."""
    gen_price = get_mean_price_by_caste(model, "General")
    sc_price = get_mean_price_by_caste(model, "SC")
    if gen_price == 0:
        return 0.0
    return (gen_price - sc_price) / gen_price * 100


def get_price_gap_st(model):
    """Raw price gap: General mean price - ST mean price."""
    gen_price = get_mean_price_by_caste(model, "General")
    st_price = get_mean_price_by_caste(model, "ST")
    if gen_price == 0:
        return 0.0
    return (gen_price - st_price) / gen_price * 100


# ==============================================================================
# MODEL CLASS
# ==============================================================================

class AgrarianMarketModel(Model):
    """
    Agent-Based Model of caste dynamics in Indian agricultural markets.

    Architecture:
      - Farmer agents initialised from NSS 77th Round empirical distributions
      - Each step = one agricultural season
      - Farmers: choose crop → produce → incur costs → choose channel → receive price → update wealth
      - Data collected at each step for analysis

    Scenarios:
      The model accepts a scenario dict (from config.SCENARIOS) that modifies
      key parameters to test policy counterfactuals.
    """

    def __init__(self, num_farmers=C.NUM_FARMERS,
                 num_districts=C.NUM_DISTRICTS,
                 scenario_name="baseline",
                 seed=C.RANDOM_SEED):

        super().__init__(seed=seed)

        self.num_farmers = num_farmers
        self.num_districts = num_districts
        self.scenario_name = scenario_name
        self.scenario = C.SCENARIOS.get(scenario_name, C.SCENARIOS["baseline"])
        self.current_season = 0

        # --- CREATE FARMER AGENTS ---
        self._create_farmers()

        # --- CREATE BUYER AGENTS (stylised) ---
        self._create_buyers()

        # --- DATA COLLECTOR ---
        self.datacollector = DataCollector(
            model_reporters={
                # Price gaps
                "Price_Gap_SC_pct": get_price_gap_sc,
                "Price_Gap_ST_pct": get_price_gap_st,
                "Gini_Income": get_gini_income,

                # Mean prices by caste
                "Price_General": lambda m: get_mean_price_by_caste(m, "General"),
                "Price_OBC":     lambda m: get_mean_price_by_caste(m, "OBC"),
                "Price_SC":      lambda m: get_mean_price_by_caste(m, "SC"),
                "Price_ST":      lambda m: get_mean_price_by_caste(m, "ST"),

                # Mean income by caste
                "Income_General": lambda m: get_mean_income_by_caste(m, "General"),
                "Income_OBC":     lambda m: get_mean_income_by_caste(m, "OBC"),
                "Income_SC":      lambda m: get_mean_income_by_caste(m, "SC"),
                "Income_ST":      lambda m: get_mean_income_by_caste(m, "ST"),

                # Wealth (MPCE)
                "MPCE_General": lambda m: get_mean_mpce(m, "General"),
                "MPCE_OBC":     lambda m: get_mean_mpce(m, "OBC"),
                "MPCE_SC":      lambda m: get_mean_mpce(m, "SC"),
                "MPCE_ST":      lambda m: get_mean_mpce(m, "ST"),

                # Channel shares for SC
                "SC_Trader_Share":  lambda m: get_channel_share(m, "SC", "LocalTrader"),
                "SC_APMC_Share":    lambda m: get_channel_share(m, "SC", "APMC"),
                "SC_Govt_Share":    lambda m: get_channel_share(m, "SC", "Government"),
                "SC_FPO_Share":     lambda m: get_channel_share(m, "SC", "FPO"),

                # Channel shares for General
                "Gen_Trader_Share": lambda m: get_channel_share(m, "General", "LocalTrader"),
                "Gen_APMC_Share":   lambda m: get_channel_share(m, "General", "APMC"),

                # Debt dynamics
                "InformalDebt_SC": lambda m: get_informal_debt_rate(m, "SC"),
                "InformalDebt_ST": lambda m: get_informal_debt_rate(m, "ST"),
                "InformalDebt_Gen": lambda m: get_informal_debt_rate(m, "General"),

                # Distress sales
                "Distress_SC": lambda m: get_distress_sale_rate(m, "SC"),
                "Distress_ST": lambda m: get_distress_sale_rate(m, "ST"),
                "Distress_Gen": lambda m: get_distress_sale_rate(m, "General"),
            },
            agent_reporters={
                "Caste":        lambda a: a.caste if isinstance(a, FarmerAgent) else None,
                "Land":         lambda a: a.land if isinstance(a, FarmerAgent) else None,
                "Crop":         lambda a: a.crop if isinstance(a, FarmerAgent) else None,
                "Channel":      lambda a: a.channel_chosen if isinstance(a, FarmerAgent) else None,
                "Price":        lambda a: a.price_received if isinstance(a, FarmerAgent) else None,
                "NetIncome":    lambda a: a.net_income if isinstance(a, FarmerAgent) else None,
                "MPCE":         lambda a: a.mpce if isinstance(a, FarmerAgent) else None,
                "InformalDebt": lambda a: a.has_informal_debt if isinstance(a, FarmerAgent) else None,
                "Satisfied":    lambda a: a.satisfied if isinstance(a, FarmerAgent) else None,
            }
        )

    def _create_farmers(self):
        """Create farmer agents with caste proportions from NSS data."""
        for caste, share in C.CASTE_DISTRIBUTION.items():
            n_caste = int(self.num_farmers * share)
            for _ in range(n_caste):
                district_id = self.random.randint(0, self.num_districts - 1)
                farmer = FarmerAgent(
                    model=self,
                    caste=caste,
                    district_id=district_id,
                    scenario=self.scenario,
                )

    def _create_buyers(self):
        """Create stylised buyer agents for each channel × district."""
        for district_id in range(self.num_districts):
            for channel in C.CHANNEL_NAMES:
                BuyerAgent(
                    model=self,
                    channel_type=channel,
                    district_id=district_id,
                )

    def step(self):
        """
        Execute one season of the model.

        All farmers simultaneously:
          1. Choose crop
          2. Produce
          3. Pay input costs
          4. Choose market channel
          5. Receive price
          6. Update wealth/debt

        Data is collected after all agents have acted.
        """
        self.current_season += 1

        # Activate all farmer agents
        farmers = [a for a in self.agents if isinstance(a, FarmerAgent)]
        for farmer in farmers:
            farmer.step()

        # Collect data
        self.datacollector.collect(self)

    def run_model(self, num_seasons=C.NUM_SEASONS):
        """Run the model for a specified number of seasons."""
        for _ in range(num_seasons):
            self.step()

    def get_summary_statistics(self):
        """Return summary statistics for the final season."""
        model_data = self.datacollector.get_model_dataframe()
        if model_data.empty:
            return {}

        last_row = model_data.iloc[-1]
        return {
            "scenario": self.scenario_name,
            "scenario_label": self.scenario.get("name", self.scenario_name),
            "seasons_run": self.current_season,
            "price_gap_sc_pct": last_row.get("Price_Gap_SC_pct", 0),
            "price_gap_st_pct": last_row.get("Price_Gap_ST_pct", 0),
            "gini_income": last_row.get("Gini_Income", 0),
            "income_general": last_row.get("Income_General", 0),
            "income_sc": last_row.get("Income_SC", 0),
            "income_st": last_row.get("Income_ST", 0),
            "sc_trader_share": last_row.get("SC_Trader_Share", 0),
            "gen_trader_share": last_row.get("Gen_Trader_Share", 0),
            "informal_debt_sc": last_row.get("InformalDebt_SC", 0),
            "informal_debt_gen": last_row.get("InformalDebt_Gen", 0),
            "distress_sc": last_row.get("Distress_SC", 0),
            "mpce_general": last_row.get("MPCE_General", 0),
            "mpce_sc": last_row.get("MPCE_SC", 0),
            "mpce_st": last_row.get("MPCE_ST", 0),
        }

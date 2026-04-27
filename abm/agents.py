# ==============================================================================
# agents.py
# Agent classes for the Agrarian Market ABM
#
# Agent Types:
#   1. FarmerAgent — agricultural household with caste, land, wealth attributes
#   2. BuyerAgent  — stylised market channel (trader, APMC, govt, coop, FPO)
#
# Calibrated from NSSO 77th Round Situation Assessment Survey (2018-19)
# ==============================================================================

import numpy as np
from mesa import Agent
from . import config as C


class FarmerAgent(Agent):
    """
    An agricultural household agent.

    Attributes initialised from NSS 77th Round empirical distributions:
      - caste: social group (General / OBC / SC / ST)
      - land: operational landholding in acres
      - mpce: monthly per capita consumer expenditure (wealth proxy)
      - crop: primary crop group grown this season
      - debt: outstanding loan amount
      - has_informal_debt: whether indebted to moneylender/trader
      - msp_aware: whether aware of Minimum Support Price
      - district_id: stylised district location

    Behavioural rules:
      1. Choose crop based on caste-specific crop distribution
      2. Decide market channel based on endowments + caste constraints
      3. Receive price determined by channel + caste penalty + debt pressure
      4. Update wealth based on net farm income
    """

    def __init__(self, model, caste, district_id, scenario=None):
        super().__init__(model)
        self.caste = caste
        self.district_id = district_id
        self.scenario = scenario or C.SCENARIOS["baseline"]

        # --- ENDOWMENTS (drawn from caste-specific distributions) ---
        self._init_land()
        self._init_wealth()
        self._init_debt()
        self._init_msp_awareness()

        # --- SEASON STATE ---
        self.crop = None
        self.qty_produced = 0.0
        self.qty_sold = 0.0
        self.channel_chosen = None
        self.price_received = 0.0
        self.revenue = 0.0
        self.input_cost = 0.0
        self.net_income = 0.0
        self.satisfied = True

        # --- HISTORY (for tracking over time) ---
        self.income_history = []
        self.wealth_history = []
        self.channel_history = []
        self.price_history = []

    # ------------------------------------------------------------------
    # INITIALISATION METHODS
    # ------------------------------------------------------------------

    def _init_land(self):
        """Draw landholding from caste-specific log-normal distribution."""
        mean_land, sd_land, prob_landless = C.LAND_PARAMS[self.caste]

        if self.random.random() < prob_landless:
            self.land = 0.0
            self.land_category = "Landless"
        else:
            # Log-normal parameterisation
            mu = np.log(max(mean_land, 0.1)) - 0.5 * np.log(1 + (sd_land / max(mean_land, 0.1)) ** 2)
            sigma = np.sqrt(np.log(1 + (sd_land / max(mean_land, 0.1)) ** 2))
            self.land = max(0.01, self.random.lognormvariate(mu, sigma))

            if self.land <= 0.5:
                self.land_category = "Marginal"
            elif self.land <= 2.0:
                self.land_category = "Small"
            elif self.land <= 5.0:
                self.land_category = "Medium"
            else:
                self.land_category = "Large"

    def _init_wealth(self):
        """Draw MPCE from caste-specific truncated normal."""
        mean_mpce, sd_mpce = C.MPCE_PARAMS[self.caste]
        self.mpce = max(500, self.random.gauss(mean_mpce, sd_mpce))

    def _init_debt(self):
        """Initialise debt status from caste-specific probabilities."""
        prob_any, prob_informal, mean_debt = C.DEBT_PROBABILITY[self.caste]

        scenario_boost = self.scenario.get("formal_credit_boost", 0.0)

        if self.random.random() < prob_any:
            self.has_debt = True
            self.debt_amount = max(0, self.random.gauss(mean_debt, mean_debt * 0.5))

            # Informal vs formal debt
            adjusted_informal_prob = prob_informal * (1 - scenario_boost)
            if self.random.random() < adjusted_informal_prob:
                self.has_informal_debt = True
                self.interest_rate = C.INFORMAL_INTEREST_RATE
            else:
                self.has_informal_debt = False
                self.interest_rate = C.FORMAL_INTEREST_RATE
        else:
            self.has_debt = False
            self.has_informal_debt = False
            self.debt_amount = 0.0
            self.interest_rate = 0.0

    def _init_msp_awareness(self):
        """Initialise MSP awareness from caste-specific probability."""
        base_prob = C.MSP_AWARENESS_PROB[self.caste]
        boost = self.scenario.get("msp_awareness_boost", 0.0)
        adjusted_prob = min(1.0, base_prob + (1.0 - base_prob) * boost)
        self.msp_aware = self.random.random() < adjusted_prob

    # ------------------------------------------------------------------
    # STEP 1: CROP SELECTION
    # ------------------------------------------------------------------

    def choose_crop(self):
        """
        Select crop for this season based on caste-specific distribution.
        In reality, crop choice depends on land type, irrigation, season,
        and market expectations. Here we use the observed aggregate
        distribution as a reduced-form approximation.
        """
        probs = C.CROP_DISTRIBUTION[self.caste]
        self.crop = self.random.choices(C.CROP_GROUPS, weights=probs, k=1)[0]

    # ------------------------------------------------------------------
    # STEP 2: PRODUCTION
    # ------------------------------------------------------------------

    def produce(self):
        """
        Calculate quantity produced based on land and crop.
        Yield = base_yield * land_acres * random_shock
        """
        if self.land <= 0 or self.crop is None:
            self.qty_produced = 0.0
            self.qty_sold = 0.0
            return

        base_yield = C.YIELD_PER_ACRE.get(self.crop, 15)
        # Random yield shock (weather, etc.) — mean 1.0, CV ~0.25
        yield_shock = max(0.3, self.random.gauss(1.0, 0.25))
        self.qty_produced = base_yield * self.land * yield_shock

        # Subtract subsistence retention
        sub_frac = C.SUBSISTENCE_FRACTION.get(self.crop, 0.15)
        self.qty_sold = max(0, self.qty_produced * (1 - sub_frac))

    # ------------------------------------------------------------------
    # STEP 3: INPUT COSTS
    # ------------------------------------------------------------------

    def incur_input_costs(self):
        """
        Calculate paid-out input expenses.
        SC/ST pay a premium due to fewer institutional input sources.
        """
        if self.land <= 0:
            self.input_cost = 0.0
            return

        mean_cost, sd_cost = C.INPUT_COST_PARAMS[self.caste]
        base_cost = max(0, self.random.gauss(mean_cost, sd_cost)) * self.land

        # Caste premium on inputs (adverse incorporation in input markets)
        premium = C.INPUT_COST_PREMIUM[self.caste]
        self.input_cost = base_cost * (1 + premium)

    # ------------------------------------------------------------------
    # STEP 4: MARKET CHANNEL CHOICE
    # ------------------------------------------------------------------

    def choose_market_channel(self):
        """
        Select market channel based on caste, land, debt, and MSP awareness.

        Decision logic:
          1. Start with caste-specific baseline probabilities
          2. Adjust for land size (larger → more APMC/formal access)
          3. If indebted to trader → higher probability of selling to trader
          4. If MSP-aware and crop is MSP-eligible → boost govt channel
          5. Apply FPO expansion scenario if active
        """
        if self.qty_sold <= 0:
            self.channel_chosen = None
            return

        # Base probabilities
        probs = list(C.CHANNEL_BASE_PROBS[self.caste])

        # Land adjustment
        for i, ch in enumerate(C.CHANNEL_NAMES):
            effect = C.LAND_CHANNEL_EFFECTS.get(ch, 0.0)
            probs[i] += effect * self.land

        # Debt-driven trader lock-in
        if self.has_informal_debt:
            # Increase trader probability, decrease others proportionally
            trader_boost = 0.15
            probs[0] += trader_boost
            for i in range(1, len(probs)):
                probs[i] -= trader_boost / (len(probs) - 1)

        # MSP awareness → boost government channel for eligible crops
        if self.msp_aware and self.crop in C.MSP_ELIGIBLE_CROPS:
            sell_prob = C.MSP_SELLING_PROB_IF_AWARE[self.caste]
            probs[2] += sell_prob * 0.5   # boost govt channel
            probs[0] -= sell_prob * 0.3   # reduce trader
            probs[5] -= sell_prob * 0.2   # reduce other

        # FPO expansion scenario
        fpo_boost = self.scenario.get("fpo_penetration_boost", 0.0)
        if fpo_boost > 0 and self.caste in ("SC", "ST"):
            probs[4] += fpo_boost          # FPO
            probs[0] -= fpo_boost * 0.7    # reduce trader
            probs[5] -= fpo_boost * 0.3    # reduce other

        # Ensure valid probability distribution
        probs = [max(0.001, p) for p in probs]
        total = sum(probs)
        probs = [p / total for p in probs]

        self.channel_chosen = self.random.choices(C.CHANNEL_NAMES, weights=probs, k=1)[0]

    # ------------------------------------------------------------------
    # STEP 5: PRICE DETERMINATION
    # ------------------------------------------------------------------

    def receive_price(self):
        """
        Determine unit price received.

        Price = base_crop_price
                × channel_multiplier
                × (1 + within_channel_caste_penalty)
                × (1 + distress_discount_if_indebted)
                × random_noise

        The caste penalty is the "unexplained" component from the
        Oaxaca-Blinder decomposition — what remains after controlling
        for endowments, crop, and geography.
        """
        if self.qty_sold <= 0 or self.channel_chosen is None:
            self.price_received = 0.0
            self.revenue = 0.0
            return

        # Base price for this crop
        base_price = C.CROP_BASE_PRICES.get(self.crop, 2000)

        # Crop price volatility
        cv = C.CROP_PRICE_VOLATILITY.get(self.crop, 0.3)
        price_shock = max(0.5, self.random.gauss(1.0, cv))
        price = base_price * price_shock

        # Channel multiplier
        ch_mult = C.CHANNEL_PRICE_MULTIPLIER.get(self.channel_chosen, 1.0)
        price *= ch_mult

        # Within-channel caste discrimination
        disc_factor = self.scenario.get("discrimination_factor", 1.0)
        ch_penalties = C.WITHIN_CHANNEL_PENALTY.get(self.channel_chosen, {})
        caste_penalty = ch_penalties.get(self.caste, 0.0) * disc_factor
        price *= np.exp(caste_penalty)    # log-linear penalty

        # Distress sale discount (debt-driven)
        if self.has_informal_debt and self.channel_chosen == "LocalTrader":
            price *= np.exp(C.DISTRESS_SALE_DISCOUNT)

        # Quantity discount for very small lots (bargaining disadvantage)
        if self.qty_sold < 5:  # less than 5 quintals
            price *= 0.95

        self.price_received = max(1.0, price)
        self.revenue = self.price_received * self.qty_sold

    # ------------------------------------------------------------------
    # STEP 6: INCOME AND WEALTH UPDATE
    # ------------------------------------------------------------------

    def update_finances(self):
        """
        Calculate net income and update wealth.

        Net income = Revenue - Input costs - Debt service
        Wealth (MPCE) adjusts based on net income relative to baseline.
        """
        # Debt service (per-season payment = annual rate / 2 × principal)
        debt_service = self.debt_amount * (self.interest_rate / 2)

        self.net_income = self.revenue - self.input_cost - debt_service

        # Satisfaction: dissatisfied if net income is negative or price below
        # expectations (simple threshold)
        self.satisfied = self.net_income > 0

        # Update wealth (MPCE proxy) — slow-moving stock
        income_per_capita = self.net_income / 5  # assume ~5 person household
        monthly_income_pc = income_per_capita / 6  # 6-month season
        # MPCE adjusts: 70% persistence + 30% new income signal
        self.mpce = max(500, 0.7 * self.mpce + 0.3 * max(500, monthly_income_pc))

        # Debt dynamics: if net income negative, debt grows
        if self.net_income < 0:
            self.debt_amount += abs(self.net_income) * 0.5  # borrow to cover losses
            # May shift to informal debt if already indebted
            if not self.has_informal_debt and self.random.random() < 0.1:
                self.has_informal_debt = True
                self.interest_rate = C.INFORMAL_INTEREST_RATE
        else:
            # Partial repayment
            repayment = min(self.debt_amount, self.net_income * 0.2)
            self.debt_amount = max(0, self.debt_amount - repayment)
            if self.debt_amount == 0:
                self.has_debt = False
                self.has_informal_debt = False

        # Record history
        self.income_history.append(self.net_income)
        self.wealth_history.append(self.mpce)
        self.channel_history.append(self.channel_chosen)
        self.price_history.append(self.price_received)

    # ------------------------------------------------------------------
    # MESA STEP
    # ------------------------------------------------------------------

    def step(self):
        """Execute one season for this farmer."""
        self.choose_crop()
        self.produce()
        self.incur_input_costs()
        self.choose_market_channel()
        self.receive_price()
        self.update_finances()


class BuyerAgent(Agent):
    """
    A stylised market channel agent.

    Buyer agents represent institutional market channels (APMC mandis,
    government procurement centres, cooperatives, FPOs) and informal
    channels (local traders). They are not explicitly modelled as
    strategic actors in this version — instead, their behaviour is
    captured through the price multipliers and caste penalties in config.

    This class exists for future extensions where buyer-side strategy
    (e.g., trader collusion, procurement quotas) can be explicitly modelled.
    """

    def __init__(self, model, channel_type, district_id):
        super().__init__(model)
        self.channel_type = channel_type
        self.district_id = district_id
        self.transactions = []
        self.total_volume = 0.0
        self.total_value = 0.0

    def record_transaction(self, farmer_id, caste, crop, qty, price):
        """Record a transaction with a farmer for analysis."""
        self.transactions.append({
            "farmer_id": farmer_id,
            "caste": caste,
            "crop": crop,
            "quantity": qty,
            "price": price,
        })
        self.total_volume += qty
        self.total_value += qty * price

    def step(self):
        """Buyer agents are passive in this version."""
        pass

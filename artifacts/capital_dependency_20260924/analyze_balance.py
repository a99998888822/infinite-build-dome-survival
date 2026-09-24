import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent


def simulate(rounds, bonus=0.0, humanity_loss=0.0, settlements=1, damage_gain=0.0,
             sanity_per_interest=0.0, rate_growth=0.0, starting_humanity=100.0):
    principal, humanity, rate, remainder, damage = 500, starting_humanity, 5 + bonus, 0.0, 0.0
    for _ in range(rounds):
        for _ in range(settlements):
            nominal = math.ceil(principal * rate / 100)
            retention = 1 / (1 + max(0, 100 - humanity) / 100)
            accrued = nominal * retention + remainder
            gain = math.floor(accrued + 1e-9)
            remainder = max(0, accrued - gain)
            principal += gain
            if gain > 0:
                damage += damage_gain
                humanity -= sanity_per_interest
                rate += rate_growth
        humanity -= humanity_loss
    return dict(principal=principal, humanity=humanity, nominal_rate=round(rate, 2),
                damage_bonus=damage, retained_interest=round(100 / (1 + max(0, 100-humanity)/100), 2))


scenarios = {
    'baseline': {},
    'one_finance_manager': {'bonus': 1.5},
    'two_finance_managers': {'bonus': 3.0},
    'sleepless_original': {'bonus': 2.0, 'humanity_loss': 3},
    'sleepless_proposed': {'bonus': 4.0, 'humanity_loss': 3},
    'frenzy_original': {'damage_gain': 2, 'sanity_per_interest': 1},
    'frenzy_proposed': {'damage_gain': 1, 'sanity_per_interest': 2},
    'frenzy_original_annuity': {'damage_gain': 2, 'sanity_per_interest': 1, 'settlements': 2},
    'frenzy_proposed_annuity': {'damage_gain': 1, 'sanity_per_interest': 2, 'settlements': 2},
    'compendium': {'rate_growth': 0.2},
    'compendium_annuity': {'rate_growth': 0.2, 'settlements': 2},
}
report = {
    'assumptions': {'principal': 500, 'base_rate': 5, 'starting_humanity': 100,
                    'combat_simulated': False, 'additional_deposits': 0,
                    'purchase_costs_included': False, 'normal_interest_ceil': True,
                    'humanity_fraction_accumulated': True, 'post_wave_sanity_loss': True},
    'scenarios': {name: {str(n): simulate(n, **params) for n in (5, 10, 15, 19)}
                  for name, params in scenarios.items()},
}
relics = json.loads((ROOT / 'data_config/relics.json').read_text(encoding='utf-8'))
report['current_relic_count'] = len(relics)
report['current_relics'] = [{k: r[k] for k in ('id', 'display_name', 'rarity', 'max_stack', 'description')}
                          for r in relics]
(OUT / 'balance_metrics.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
for name, data in report['scenarios'].items():
    print(name, data['10'], '19 waves:', data['19'])

# Existing assets only: this sheet is a style reference, not newly generated icons.
from PIL import Image, ImageDraw
ids = ['relic_steel_vault', 'relic_quant_trading', 'relic_hostile_takeover',
       'relic_compound_interest_tome', 'relic_dividend_check', 'relic_holy_silver_cup',
       'relic_reincarnation_hellfire_candle', 'relic_guarding_heart_copper_mirror']
sheet = Image.new('RGB', (768, 384), '#18231e')
for i, rid in enumerate(ids):
    source = Image.open(ROOT / 'assets/ui/icons/relics' / (rid + '.png')).convert('RGBA')
    icon = source.resize((128, 128), Image.Resampling.NEAREST)
    x, y = (i % 4)*192+32, (i//4)*192+24
    sheet.paste(icon, (x, y), icon)
    ImageDraw.Draw(sheet).text((x, y+135), rid.removeprefix('relic_'), fill='#d9d0af')
sheet.save(OUT / 'existing_style_reference.png')

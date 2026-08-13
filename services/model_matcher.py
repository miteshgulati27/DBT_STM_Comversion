import re
from pathlib import Path


def match_models(stm_tabs: dict, sql_filenames: list) -> list:
    models = []
    matched_tabs = set()

    for sql_file in sql_filenames:
        model_name = Path(sql_file).stem
        entity_name = _extract_entity_name(model_name)

        best_tab = _find_best_tab_match(entity_name, stm_tabs.keys())
        if best_tab:
            matched_tabs.add(best_tab)

        models.append({
            "model_name": model_name,
            "stm_tab": best_tab,
            "column_count": stm_tabs[best_tab]["column_count"] if best_tab else 0,
            "has_sql": True,
        })

    for tab_name, tab_info in stm_tabs.items():
        if tab_name not in matched_tabs:
            models.append({
                "model_name": f"(unmatched) {tab_name}",
                "stm_tab": tab_name,
                "column_count": tab_info["column_count"],
                "has_sql": False,
            })

    return models


ENTITY_ALIASES = {
    "privpas": ["private passenger", "privatepassenger", "pp", "privpas"],
    "publictrans": ["public transport", "publictransport", "pt", "publictrans"],
    "specialtype": ["special type", "specialtype", "st"],
    "truck": ["ca vehicle (truck)", "vehicle truck"],
    "zonerated": ["zone rated", "zonerated", "zr"],
    "covgterm_truck": ["ca coverage term (veh - truck)", "coverage term veh truck", "coverage term truck"],
    "condterm_truck": ["ca condition term (veh - truck)", "condition term veh truck"],
    "exclterm_truck": ["ca exclusion term (veh - truck)", "exclusion term veh truck"],
    "covgterm_privpas": ["ca coverage term (veh - pp)", "coverage term veh pp", "coverage term private passenger"],
    "covgterm_publictrans": ["ca coverage term (veh - pt)", "coverage term veh pt"],
    "covgterm_specialtype": ["ca coverage term (veh - st)", "coverage term veh st"],
    "covgterm_zonerated": ["ca coverage term (veh - zr)", "coverage term veh zr"],
    "covgterm_policyline": ["ca coverage term (policy line)", "coverage term policy line"],
    "covgterm_juris": ["ca coverage term (juris)", "coverage term juris"],
    "building": ["building", "bp_building"],
    "location": ["location", "bp_location"],
    "classification": ["classification", "bp_classification"],
    "jurisdiction": ["jurisdiction", "jurs", "juris"],
    "dealer": ["dealer"],
    "driver": ["driver"],
    "garagesvc": ["garage service", "garageservice", "garage svc"],
    "namedind": ["named individual", "namedindividual", "named ind"],
    "policyline": ["policy line", "policyline"],
    "scheditem": ["scheduled item", "scheduleditem"],
    "premtran": ["premium transaction", "premiumtransaction", "prem tran"],
    "modifier": ["modifier"],
}


def _extract_entity_name(model_name: str) -> str:
    name = model_name.lower()
    name = re.sub(r"^(int|stg|dim|fct|mart)_", "", name)
    name = re.sub(r"^gwpc_", "", name)
    name = re.sub(r"^(bop|ca|wc|gl|im|cpkg)_", "", name)
    name = re.sub(r"_(cvrbl|coverable|dim|fct|stg)$", "", name)
    return name


def _find_best_tab_match(entity_name: str, tab_names) -> str | None:
    entity_lower = entity_name.lower().replace("_", "")

    for tab in tab_names:
        tab_lower = tab.lower().replace("_", "").replace(" ", "")
        if entity_lower == tab_lower:
            return tab

    aliases = ENTITY_ALIASES.get(entity_name.lower(), []) or ENTITY_ALIASES.get(entity_name.lower().replace("_", ""), [])
    if aliases:
        candidates = []
        for alias in aliases:
            alias_clean = alias.lower().replace(" ", "").replace("(", "").replace(")", "")
            for tab in tab_names:
                tab_lower = tab.lower().replace(" ", "").replace("_", "").replace("(", "").replace(")", "").replace("-", "")
                if alias_clean.replace(" ", "").replace("(", "").replace(")", "") in tab_lower:
                    candidates.append(tab)
        if candidates:
            vehicle_tabs = [t for t in candidates if "vehicle" in t.lower()]
            if vehicle_tabs:
                return vehicle_tabs[0]
            non_term_tabs = [t for t in candidates if "term" not in t.lower()]
            if non_term_tabs:
                return non_term_tabs[0]
            return candidates[0]

    for tab in tab_names:
        tab_lower = tab.lower().replace("_", "").replace(" ", "")
        if entity_lower in tab_lower or tab_lower in entity_lower:
            return tab

    return None

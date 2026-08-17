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
    # CA Coverage Term aliases
    "covgterm_truck": ["ca coverage term (veh - truck)"],
    "covgterm_privpas": ["ca coverage term (veh - pp)"],
    "covgterm_publictrans": ["ca coverage term (veh - pt)"],
    "covgterm_specialtype": ["ca coverage term (veh - st)"],
    "covgterm_zonerated": ["ca coverage term (veh - zr)"],
    "covgterm_policyline": ["ca coverage term (policy line)"],
    "covgterm_juris": ["ca coverage term (juris)"],
    "covgterm_dealer": ["ca coverage term (dealer)"],
    "covgterm_garagesvc": ["ca coverage term (garage svc)"],
    "covgterm_namedind": ["ca coverage term (named ind)"],
    "covgterm_linecovgsi": ["ca coverage term (linecovgsi)"],
    "covgterm_dealercovgsi": ["ca coverage term (dealercovgsi)"],
    "covgterm_juriscovgsi": ["ca coverage term (juriscovgsi)"],
    "covgterm_gscovgsi": ["ca coverage term (gscovgsi)"],
    "covgterm_ppcovgsi": ["ca coverage term (ppcovgsi)"],
    "covgterm_ptcovgsi": ["ca coverage term (ptcovgsi)"],
    "covgterm_stcovgsi": ["ca coverage term (stcovgsi)"],
    "covgterm_truckcovgsi": ["ca coverage term (truckcovgsi)"],
    "covgterm_zrcovgsi": ["ca coverage term (zrcovgsi)"],
    # CA Condition Term aliases
    "condterm_truck": ["ca condition term (veh - truck)"],
    "condterm_privpas": ["ca condition term (veh - pp)"],
    "condterm_publictrans": ["ca condition term (veh - pt)"],
    "condterm_specialtype": ["ca condition term (veh - st)"],
    "condterm_zonerated": ["ca condition term (veh - zr)"],
    "condterm_policyline": ["ca condition term (policy line)"],
    "condterm_juris": ["ca condition term (juris)"],
    "condterm_dealer": ["ca condition term (dealer)"],
    "condterm_garagesvc": ["ca condition term (garage svc)"],
    "condterm_namedind": ["ca condition term (named ind)"],
    # CA Exclusion Term aliases
    "exclterm_truck": ["ca exclusion term (veh - truck)"],
    "exclterm_privpas": ["ca exclusion term (veh - pp)"],
    "exclterm_publictrans": ["ca exclusion term (veh - pt)"],
    "exclterm_specialtype": ["ca exclusion term (veh - st)"],
    "exclterm_zonerated": ["ca exclusion term (veh - zr)"],
    "exclterm_policyline": ["ca exclusion term (policy line)"],
    "exclterm_juris": ["ca exclusion term (juris)"],
    "exclterm_dealer": ["ca exclusion term (dealer)"],
    "exclterm_garagesvc": ["ca exclusion term (garage svc)"],
    "exclterm_namedind": ["ca exclusion term (named ind)"],
    # CA Vehicle aliases
    "cvrbl": ["ca vehicle (private passenger)"],
    "privpas": ["ca vehicle (private passenger)", "private passenger"],
    "publictrans": ["ca vehicle (public transport)", "public transport"],
    "specialtype": ["ca vehicle (special type)", "special type"],
    "truck": ["ca vehicle (truck)"],
    "zonerated": ["ca vehicle (zone rated)", "zone rated"],
    # CA Entity aliases
    "polline": ["ca policy line", "bop policy line", "policy line"],
    "jurisdiction": ["ca jurisdiction", "jurisdiction"],
    "dealer": ["ca dealer", "dealer"],
    "driver": ["ca driver", "driver"],
    "garagesvc": ["ca garage service", "garage service"],
    "namedind": ["ca named individual", "named individual"],
    "scheditem": ["ca scheduled item", "scheduled item"],
    "scheditem_line_cond": ["ca scheduled item"],
    "scheditem_line_covg": ["ca scheduled item"],
    "scheditem_line_excl": ["ca scheduled item"],
    "scheditem_dealer_covg": ["ca scheduled item"],
    "scheditem_dealer_excl": ["ca scheduled item"],
    "scheditem_garagesvc_covg": ["ca scheduled item"],
    "scheditem_juris_covg": ["ca scheduled item"],
    "scheditem_juris_excl": ["ca scheduled item"],
    "scheditem_pp_covg": ["ca scheduled item"],
    "scheditem_pt_covg": ["ca scheduled item"],
    "scheditem_st_covg": ["ca scheduled item"],
    "scheditem_truck_covg": ["ca scheduled item"],
    "scheditem_zr_covg": ["ca scheduled item"],
    "linesicond": ["ca line sched item condition", "line sched item condition"],
    "modifier": ["ca modifier", "bop modifier (1)", "modifier"],
    "ratefactor": ["ca modifier rate factor", "bop modifier rate factor (1)", "modifier rate factor"],
    "additionalintrst": ["ca additional interest", "bop additional interest", "additional interest"],
    "premtxn": ["ca premium transaction", "bop premium transaction", "premium transaction"],
    # BOP aliases
    "bldg": ["bop building", "building"],
    "sblocation": ["bop location", "location"],
    "classification": ["classification", "coverable type master"],
    "condterm": ["bop condition term (1)", "condition term"],
    "condterm_polline": ["bop condition term (1)"],
    "covgterm": ["bop coverage term (1)", "coverage term"],
    "covgterm_bldg": ["bop coverage term (2)"],
    "covgterm_polline": ["bop coverage term (3)"],
    "covgterm_sblocation": ["bop coverage term (2)"],
    "exclterm": ["bop exclusion term (1)", "exclusion term"],
    "exclterm_polline": ["bop exclusion term (1)"],
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
            alias_clean = alias.lower().replace(" ", "").replace("(", "").replace(")", "").replace("-", "")
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

import json
from datetime import datetime
from flask import Blueprint, jsonify, request
from server.config import STM_DIR, SQL_DIR, MACROS_DIR
from services.comparator import run_comparison

compare_bp = Blueprint("compare", __name__)


LOB_CONFIG = {
    "bop": {"stm_file": "Businessowners Policy Data Specifications.xlsm", "sql_folder": "bop"},
    "ca": {"stm_file": "Commercial Auto Data Specifications.xlsx", "sql_folder": "ca"},
}


@compare_bp.route("/compare", methods=["POST"])
def compare():
    data = request.get_json()
    models = data.get("models", [])
    lob = data.get("lob", "")

    if not models:
        return jsonify({"error": "No models specified"}), 400

    if lob and lob in LOB_CONFIG:
        config = LOB_CONFIG[lob]
        stm_path = STM_DIR / config["stm_file"]
        sql_dir = SQL_DIR / config["sql_folder"]
    else:
        stm_files = list(STM_DIR.glob("*.xlsx")) + list(STM_DIR.glob("*.xls")) + list(STM_DIR.glob("*.xlsm"))
        if not stm_files:
            return jsonify({"error": "No STM file found"}), 400
        stm_path = stm_files[0]
        sql_dir = SQL_DIR

    if not stm_path.exists():
        return jsonify({"error": f"STM file not found: {stm_path.name}"}), 400

    results = {}

    for model_name in models:
        try:
            result = run_comparison(model_name, stm_path, sql_dir, MACROS_DIR)
            results[model_name] = result
        except Exception as e:
            results[model_name] = {"error": str(e), "summary": {}, "detailed": []}

    return jsonify({"results": results})

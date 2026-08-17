from flask import Blueprint, jsonify, request
from server.config import STM_DIR, SQL_DIR
from services.excel_parser import parse_stm_workbook, get_tab_columns
from services.model_matcher import match_models

models_bp = Blueprint("models", __name__)

LOB_CONFIG = {
    "bop": {"stm_file": "Businessowners Policy Data Specifications.xlsm", "sql_folder": "bop"},
    "ca": {"stm_file": "Commercial Auto Data Specifications.xlsx", "sql_folder": "ca"},
}


def _get_paths(lob):
    if lob and lob in LOB_CONFIG:
        config = LOB_CONFIG[lob]
        return STM_DIR / config["stm_file"], SQL_DIR / config["sql_folder"]
    stm_files = list(STM_DIR.glob("*.xlsx")) + list(STM_DIR.glob("*.xls")) + list(STM_DIR.glob("*.xlsm"))
    return (stm_files[0] if stm_files else None), SQL_DIR


@models_bp.route("/models", methods=["GET"])
def list_models():
    lob = request.args.get("lob", "")
    stm_path, sql_dir = _get_paths(lob)
    if not stm_path or not stm_path.exists():
        return jsonify({"models": []})

    stm_tabs = parse_stm_workbook(stm_path)
    sql_files = [f.name for f in sql_dir.glob("*.sql")] if sql_dir.exists() else []
    models = match_models(stm_tabs, sql_files)
    return jsonify({"models": models})


@models_bp.route("/models/<model_name>/details", methods=["GET"])
def model_details(model_name):
    lob = request.args.get("lob", "")
    stm_path, sql_dir = _get_paths(lob)

    if not stm_path or not stm_path.exists():
        return jsonify({"error": "No STM file found"}), 404

    stm_tabs = parse_stm_workbook(stm_path)
    sql_files = [f.name for f in sql_dir.glob("*.sql")] if sql_dir.exists() else []
    models = match_models(stm_tabs, sql_files)

    model = next((m for m in models if m["model_name"] == model_name), None)
    if not model:
        return jsonify({"error": f"Model {model_name} not found"}), 404

    if model["stm_tab"]:
        columns = get_tab_columns(stm_path, model["stm_tab"])
        return jsonify({"model_name": model_name, "stm_tab": model["stm_tab"], "columns": columns})

    return jsonify({"model_name": model_name, "stm_tab": None, "columns": []})


@models_bp.route("/models/<model_name>/sql", methods=["GET"])
def model_sql(model_name):
    lob = request.args.get("lob", "")
    _, sql_dir = _get_paths(lob)

    sql_path = sql_dir / f"{model_name}.sql"
    if not sql_path.exists():
        return jsonify({"error": f"SQL file not found: {model_name}.sql"}), 404

    content = sql_path.read_text(encoding="utf-8")
    return jsonify({
        "model_name": model_name,
        "filename": f"{model_name}.sql",
        "content": content,
        "line_count": content.count("\n") + 1,
    })


@models_bp.route("/models/<model_name>/compiled", methods=["GET"])
def model_compiled(model_name):
    lob = request.args.get("lob", "")
    _, sql_dir = _get_paths(lob)

    sql_path = sql_dir / f"{model_name}.sql"
    if not sql_path.exists():
        return jsonify({"error": f"SQL file not found: {model_name}.sql"}), 404

    from server.config import MACROS_DIR
    from services.dbt_compiler import compile_sql
    from services.comparator import _resolve_ref_model

    try:
        resolved_path = _resolve_ref_model(sql_path, sql_dir)
        compiled_content = compile_sql(resolved_path, MACROS_DIR)

        if resolved_path != sql_path:
            header = f"-- Source: {model_name}.sql resolves to {resolved_path.name}\n"
            header += f"-- Original: {sql_path.read_text(encoding='utf-8').strip()}\n"
            header += "-- Compiled sub-model shown below:\n\n"
            compiled_content = header + compiled_content
    except Exception as e:
        return jsonify({"error": f"Compilation error: {str(e)}"}), 500

    return jsonify({
        "model_name": model_name,
        "filename": f"{model_name}.sql",
        "content": compiled_content,
        "line_count": compiled_content.count("\n") + 1,
    })

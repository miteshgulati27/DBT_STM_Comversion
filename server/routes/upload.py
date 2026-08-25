import os
import csv
import shutil
from flask import Blueprint, request, jsonify
from werkzeug.utils import secure_filename
from server.config import STM_DIR, SQL_DIR, MACROS_DIR, MAPPINGS_DIR, ALLOWED_STM_EXTENSIONS, ALLOWED_SQL_EXTENSIONS, LOB_CONFIG
from services.excel_parser import parse_stm_workbook
from services.model_matcher import match_models

upload_bp = Blueprint("upload", __name__)


@upload_bp.route("/lobs", methods=["GET"])
def list_lobs():
    """List available LOBs with file counts."""
    lobs = []
    for lob_id, config in LOB_CONFIG.items():
        stm_path = STM_DIR / config["stm_file"]
        sql_folder = SQL_DIR / config["sql_folder"]
        sql_count = len(list(sql_folder.glob("*.sql"))) if sql_folder.exists() else 0

        short_name = "".join(w[0] for w in config["name"].split() if w).upper()

        lobs.append({
            "id": lob_id,
            "name": config["name"],
            "short_name": short_name,
            "stm_file": config["stm_file"],
            "stm_exists": stm_path.exists(),
            "sql_count": sql_count,
        })
    return jsonify({"lobs": lobs})


@upload_bp.route("/lobs/<lob_id>/models", methods=["GET"])
def list_lob_models(lob_id):
    """List models for a specific LOB, driven by the mapping CSV."""
    if lob_id not in LOB_CONFIG:
        return jsonify({"error": f"Unknown LOB: {lob_id}"}), 400

    config = LOB_CONFIG[lob_id]
    mapping_file = MAPPINGS_DIR / config["mapping_file"]

    models = []
    with open(mapping_file, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            sql_model = row["SQL Model"].strip()
            stm_tab = row["STM Tab"].strip() if row["STM Tab"].strip() else None
            models.append({
                "model_name": sql_model,
                "stm_tab": stm_tab,
                "column_count": 0,
                "has_sql": True,
            })

    # Enrich with actual column counts from STM
    stm_path = STM_DIR / config["stm_file"]
    if stm_path.exists():
        try:
            stm_tabs = parse_stm_workbook(stm_path)
            for model in models:
                if model["stm_tab"] and model["stm_tab"] in stm_tabs:
                    model["column_count"] = stm_tabs[model["stm_tab"]]["column_count"]
        except Exception:
            pass

    return jsonify({"lob": lob_id, "models": models})


@upload_bp.route("/detect-existing", methods=["GET"])
def detect_existing():
    """Check if files already exist in data/ folders."""
    lobs_with_files = []
    for lob_id, config in LOB_CONFIG.items():
        stm_path = STM_DIR / config["stm_file"]
        sql_folder = SQL_DIR / config["sql_folder"]
        if stm_path.exists() and sql_folder.exists() and list(sql_folder.glob("*.sql")):
            lobs_with_files.append(lob_id)

    return jsonify({"has_files": len(lobs_with_files) > 0, "lobs": lobs_with_files})


@upload_bp.route("/upload", methods=["POST"])
def upload_files():
    for d in [STM_DIR, SQL_DIR, MACROS_DIR]:
        if d.exists():
            shutil.rmtree(d)
        d.mkdir(parents=True, exist_ok=True)

    stm_file = request.files.get("stm")
    if not stm_file:
        return jsonify({"error": "STM workbook is required"}), 400

    ext = os.path.splitext(stm_file.filename)[1].lower()
    if ext not in ALLOWED_STM_EXTENSIONS:
        return jsonify({"error": f"Invalid STM file type: {ext}"}), 400

    stm_path = STM_DIR / secure_filename(stm_file.filename)
    stm_file.save(str(stm_path))

    sql_files = request.files.getlist("sql_files")
    sql_filenames = []
    for f in sql_files:
        if f.filename and os.path.splitext(f.filename)[1].lower() in ALLOWED_SQL_EXTENSIONS:
            fname = secure_filename(f.filename)
            f.save(str(SQL_DIR / fname))
            sql_filenames.append(fname)

    macro_files = request.files.getlist("macro_files")
    for f in macro_files:
        if f.filename and os.path.splitext(f.filename)[1].lower() in ALLOWED_SQL_EXTENSIONS:
            fname = secure_filename(f.filename)
            f.save(str(MACROS_DIR / fname))

    try:
        stm_tabs = parse_stm_workbook(stm_path)
        models = match_models(stm_tabs, sql_filenames)
    except Exception as e:
        return jsonify({"error": f"Error parsing files: {str(e)}"}), 500

    return jsonify({
        "stm_file": stm_file.filename,
        "sql_files_count": len(sql_filenames),
        "macro_files_count": len(macro_files),
        "models": models
    })

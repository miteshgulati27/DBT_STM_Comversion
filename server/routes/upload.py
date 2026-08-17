import os
import shutil
from flask import Blueprint, request, jsonify
from werkzeug.utils import secure_filename
from server.config import STM_DIR, SQL_DIR, MACROS_DIR, ALLOWED_STM_EXTENSIONS, ALLOWED_SQL_EXTENSIONS
from services.excel_parser import parse_stm_workbook
from services.model_matcher import match_models

upload_bp = Blueprint("upload", __name__)

LOB_CONFIG = {
    "bop": {
        "name": "Business Owners Policy",
        "stm_file": "Businessowners Policy Data Specifications.xlsm",
        "sql_folder": "bop",
    },
    "ca": {
        "name": "Commercial Auto",
        "stm_file": "Commercial Auto Data Specifications.xlsx",
        "sql_folder": "ca",
    },
}


@upload_bp.route("/lobs", methods=["GET"])
def list_lobs():
    """List available LOBs with file counts."""
    lobs = []
    for lob_id, config in LOB_CONFIG.items():
        stm_path = STM_DIR / config["stm_file"]
        sql_folder = SQL_DIR / config["sql_folder"]
        sql_count = len(list(sql_folder.glob("*.sql"))) if sql_folder.exists() else 0

        lobs.append({
            "id": lob_id,
            "name": config["name"],
            "stm_file": config["stm_file"],
            "stm_exists": stm_path.exists(),
            "sql_count": sql_count,
        })
    return jsonify({"lobs": lobs})


@upload_bp.route("/lobs/<lob_id>/models", methods=["GET"])
def list_lob_models(lob_id):
    """List models for a specific LOB."""
    if lob_id not in LOB_CONFIG:
        return jsonify({"error": f"Unknown LOB: {lob_id}"}), 400

    config = LOB_CONFIG[lob_id]
    stm_path = STM_DIR / config["stm_file"]
    sql_folder = SQL_DIR / config["sql_folder"]

    if not stm_path.exists():
        return jsonify({"error": f"STM file not found: {config['stm_file']}"}), 404

    if not sql_folder.exists():
        return jsonify({"error": f"SQL folder not found: {config['sql_folder']}"}), 404

    sql_filenames = [f.name for f in sql_folder.glob("*.sql")]

    try:
        stm_tabs = parse_stm_workbook(stm_path)
        models = match_models(stm_tabs, sql_filenames)
    except Exception as e:
        return jsonify({"error": f"Error parsing: {str(e)}"}), 500

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

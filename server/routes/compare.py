import json
import shutil
from datetime import datetime, timedelta
from pathlib import Path
from flask import Blueprint, jsonify, request, send_file
from server.config import STM_DIR, SQL_DIR, MACROS_DIR, RESULTS_DIR, RESULTS_RETENTION_DAYS
from services.comparator import run_comparison
from services.report_generator import generate_xlsx

compare_bp = Blueprint("compare", __name__)


LOB_CONFIG = {
    "bop": {"stm_file": "Businessowners Policy Data Specifications.xlsm", "sql_folder": "bop"},
    "ca": {"stm_file": "Commercial Auto Data Specifications.xlsx", "sql_folder": "ca"},
}


def _purge_old_results():
    """Remove result folders older than RESULTS_RETENTION_DAYS."""
    if not RESULTS_DIR.exists():
        return
    cutoff = datetime.now() - timedelta(days=RESULTS_RETENTION_DAYS)
    for d in RESULTS_DIR.iterdir():
        if d.is_dir():
            try:
                dir_date = datetime.strptime(d.name.split("_")[0], "%Y-%m-%d")
                if dir_date < cutoff:
                    shutil.rmtree(d)
            except (ValueError, IndexError):
                pass


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

    _purge_old_results()

    results = {}
    log_lines = [f"Run started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"]
    log_lines.append(f"LOB: {lob or 'auto'}")
    log_lines.append(f"STM file: {stm_path.name}")
    log_lines.append(f"Models to compare: {len(models)}\n")

    for model_name in models:
        log_lines.append(f"[{datetime.now().strftime('%H:%M:%S')}] Processing: {model_name}")

        timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        run_dir = RESULTS_DIR / f"{model_name}_{timestamp}"
        run_dir.mkdir(parents=True, exist_ok=True)

        try:
            result = run_comparison(model_name, stm_path, sql_dir, MACROS_DIR)
            results[model_name] = result

            xlsx_path = run_dir / f"{model_name}.xlsx"
            generate_xlsx(result, xlsx_path)

            summary = result["summary"]
            log_lines.append(f"  STM tab: {result.get('stm_tab', '?')} ({summary['total_stm_columns']} columns)")
            log_lines.append(f"  Comparison complete: {summary['matched_columns']} MATCH, {summary['datatype_mismatches']} MISMATCH")
            log_lines.append(f"  Output: {run_dir.name}/{model_name}.xlsx\n")
        except Exception as e:
            log_lines.append(f"  ERROR: {str(e)}\n")
            results[model_name] = {"error": str(e), "summary": {}, "detailed": []}

        log_path = run_dir / "run_log.txt"
        log_path.write_text("\n".join(log_lines), encoding="utf-8")

        results_json = run_dir / "results.json"
        results_json.write_text(json.dumps(results, default=str, indent=2), encoding="utf-8")

    return jsonify({"results": results})


@compare_bp.route("/results/download/<model_name>", methods=["GET"])
def download_result(model_name):
    result_dirs = sorted(RESULTS_DIR.iterdir(), reverse=True)
    for d in result_dirs:
        if d.is_dir() and d.name.startswith(model_name):
            xlsx_path = d / f"{model_name}.xlsx"
            if xlsx_path.exists():
                return send_file(str(xlsx_path), as_attachment=True, download_name=f"{model_name}.xlsx")
    return jsonify({"error": "File not found"}), 404


@compare_bp.route("/results/download-all", methods=["GET"])
def download_all():
    import zipfile
    import io

    result_dirs = sorted(RESULTS_DIR.iterdir(), reverse=True)
    if not result_dirs:
        return jsonify({"error": "No results available"}), 404

    latest_dir = next((d for d in result_dirs if d.is_dir()), None)
    if not latest_dir:
        return jsonify({"error": "No results available"}), 404

    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as zf:
        for f in latest_dir.iterdir():
            zf.write(f, f.name)

    buffer.seek(0)
    return send_file(buffer, as_attachment=True, download_name=f"comparison_results_{latest_dir.name}.zip", mimetype="application/zip")

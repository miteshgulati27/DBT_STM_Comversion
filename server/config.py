import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = Path(os.getenv("DATA_DIR", str(BASE_DIR / "data")))
UPLOAD_DIR = BASE_DIR / "server" / "uploads"

STM_DIR = DATA_DIR / "stm"
SQL_DIR = DATA_DIR / "sql"
MACROS_DIR = DATA_DIR / "macros"
RESULTS_DIR = DATA_DIR / "results"
MAPPINGS_DIR = DATA_DIR / "mappings"

ALLOWED_STM_EXTENSIONS = {".xlsx", ".xls", ".xlsm"}
ALLOWED_SQL_EXTENSIONS = {".sql"}
ALLOWED_MACRO_EXTENSIONS = {".sql"}

MAX_CONTENT_LENGTH = 50 * 1024 * 1024  # 50MB

ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")


def discover_lobs():
    """Auto-discover LOBs by matching all three: STM file + SQL folder + mapping CSV by name."""
    lobs = {}
    if not STM_DIR.exists():
        return lobs

    for stm_file in STM_DIR.iterdir():
        if stm_file.suffix.lower() in ALLOWED_STM_EXTENSIONS:
            lob_name = stm_file.stem
            sql_folder = SQL_DIR / lob_name
            mapping_file = MAPPINGS_DIR / f"{lob_name}_mapping.csv"
            if sql_folder.exists() and sql_folder.is_dir() and mapping_file.exists():
                lob_id = lob_name.lower().replace(" ", "_")
                lobs[lob_id] = {
                    "name": lob_name,
                    "stm_file": stm_file.name,
                    "sql_folder": lob_name,
                    "mapping_file": mapping_file.name,
                }
    return lobs


LOB_CONFIG = discover_lobs()

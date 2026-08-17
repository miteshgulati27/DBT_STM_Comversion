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

ALLOWED_STM_EXTENSIONS = {".xlsx", ".xls", ".xlsm"}
ALLOWED_SQL_EXTENSIONS = {".sql"}
ALLOWED_MACRO_EXTENSIONS = {".sql"}

MAX_CONTENT_LENGTH = 50 * 1024 * 1024  # 50MB

ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")

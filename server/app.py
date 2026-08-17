import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from flask import Flask
from flask_cors import CORS
from server.config import MAX_CONTENT_LENGTH, DATA_DIR, STM_DIR, SQL_DIR, MACROS_DIR
from server.routes.upload import upload_bp
from server.routes.models import models_bp
from server.routes.compare import compare_bp


def create_app():
    app = Flask(__name__, template_folder="templates", static_folder="static")
    app.config["MAX_CONTENT_LENGTH"] = MAX_CONTENT_LENGTH
    app.config["SECRET_KEY"] = "dev-secret-key"
    CORS(app)

    for d in [DATA_DIR, STM_DIR, SQL_DIR, MACROS_DIR]:
        d.mkdir(parents=True, exist_ok=True)

    app.register_blueprint(upload_bp, url_prefix="/api")
    app.register_blueprint(models_bp, url_prefix="/api")
    app.register_blueprint(compare_bp, url_prefix="/api")

    from server.routes.pages import pages_bp
    app.register_blueprint(pages_bp)

    return app


if __name__ == "__main__":
    app = create_app()
    app.run(debug=True, port=5000)

import os

import uvicorn

from . import error_boundary as _error_boundary
from . import probes as _probes
from . import routes as _routes
from .lifespan import app


def main() -> None:
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ["DATALK_PORT"]))


if __name__ == "__main__":
    main()

from fastapi import Request, Response

from .lifespan import app


@app.get("/livez")
async def livez() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/readyz")
async def readyz(request: Request, response: Response) -> dict[str, str]:
    if not request.app.state.worker.ready:
        response.status_code = 503
        return {"status": "starting"}

    return {"status": "ready"}

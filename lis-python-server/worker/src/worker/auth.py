import hmac

from fastapi import Header, Request

from .error_boundary import WorkerProtocolError


def authenticate(
    request: Request,
    authorization: str | None = Header(default=None),
) -> None:
    state = request.app.state.worker
    expected = f"Bearer {state.config.token}"
    if authorization is None or not hmac.compare_digest(authorization, expected):
        raise WorkerProtocolError(
            status=401,
            code="authentication_failed",
            message="worker authentication failed",
        )

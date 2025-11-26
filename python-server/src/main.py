#! /usr/bin/env python

import asyncio
from asyncio import TimeoutError, wait_for
from typing import Literal

import pandas as pd
from fastapi import FastAPI, HTTPException
from jupyter_client.asynchronous.client import AsyncKernelClient
from jupyter_client.manager import AsyncKernelManager
from pydantic import BaseModel

from . import data_source

app = FastAPI()

KERNELS: dict[str, tuple[AsyncKernelManager, AsyncKernelClient]] = {}
DATA_SOURCES: dict[str, list[str]] = {}


class ExecutionRequest(BaseModel):
    chat_id: str
    code: list[str]
    language: Literal["python"] | Literal["sql"]


class ExecutionResult(BaseModel):
    outputs: str


async def kernel_client() -> tuple[AsyncKernelManager, AsyncKernelClient]:
    km = AsyncKernelManager(kernel_name="python3")
    await km.start_kernel()
    kc = km.client()
    kc.start_channels()
    await kc.wait_for_ready()
    return km, kc


async def execute_code(kc: AsyncKernelClient, code: str) -> str:
    print(code)
    msg_id = kc.execute(code)
    try:
        while True:
            reply = await kc.get_iopub_msg()
            if reply["parent_header"]["msg_id"] != msg_id:
                continue
            msg_type = reply["msg_type"]
            if msg_type == "stream":
                return reply["content"]["text"]
            elif msg_type == "error":
                return f"Error executing code: {reply['content']['evalue']}"
            elif msg_type == "status" and reply["content"]["execution_state"] == "idle":
                break
    except asyncio.CancelledError:
        raise
    return ""


@app.post("/execute", response_model=ExecutionResult)
async def execute(request: ExecutionRequest) -> ExecutionResult:
    if request.chat_id not in KERNELS:
        raise HTTPException(
            status_code=400,
            detail=f"Execution environment not yet created for {request.chat_id}",
        )

    try:
        _, kc = KERNELS[request.chat_id]
        match request.language:
            case "python":
                code = "\n".join(request.code)
            case "sql":
                code_without_newlines = [
                    line.replace("\n", " ") for line in request.code
                ]
                code = f"""
                import duckdb
                sql_output = duckdb.sql('''{"\n".join(code_without_newlines)}''').df()
                print(sql_output)
                """
        outputs = await wait_for(
            execute_code(kc=kc, code=code),
            timeout=120,
        )

        print(outputs)
    except TimeoutError:
        raise HTTPException(status_code=400, detail="Code execution timed out")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    return ExecutionResult(outputs=outputs)


class EnvironmentCreationRequest(BaseModel):
    chat_id: str
    # enabled_data_sources: list[str]


class EnvironmentCreationResponse(BaseModel):
    # available_dataframes: list[tuple[str, pd.Index, tuple[int, int]]]
    available_dataframes: str


class EnvironmentDeletionRequest(BaseModel):
    chat_id: str


@app.post("/environment/create")
async def create_kernel(
    request: EnvironmentCreationRequest,
) -> EnvironmentCreationResponse:
    if request.chat_id not in KERNELS:
        km, kc = await kernel_client()
        KERNELS[request.chat_id] = (km, kc)
        _ = kc.execute("""
            import pandas as pd
            cfbd_2025_games = pd.read_csv('./cfbd_2025_games.csv')
            cfbd_2025_lines = pd.read_csv('./cfbd_2025_lines.csv')
        """)
    else:
        _, kc = KERNELS[request.chat_id]

    available_dataframes = await execute_code(
        kc=kc,
        code="""
        print([
            (var, val.columns, val.shape) 
            for var, val in globals().items()
            if type(val) is pd.core.frame.DataFrame and not var.startswith('_')
        ])
    """,
    )

    return EnvironmentCreationResponse(available_dataframes=available_dataframes)


@app.post("/environment/destroy")
async def destroy_kernel(request: EnvironmentDeletionRequest):
    if request.chat_id in KERNELS:
        km, kc = KERNELS[request.chat_id]
        kc.stop_channels()
        await km.shutdown_kernel()
        del KERNELS[request.chat_id]
    return


@app.get("/environment/exists")
def environment_exists(chat_id: str) -> bool:
    return chat_id in KERNELS


# @app.get("/data/list")
# def get_available_data_sources(chat_id: str) -> list[str]:
#     return DATA_SOURCES.get(chat_id, [])


# @app.post("/data/allow")
# def grant_user_access_to_source(chat_id: str, data_source_name: str):
#     DATA_SOURCES[chat_id] = DATA_SOURCES.get(chat_id, []) + [data_source_name]
#     return


def main():
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)


if __name__ == "__main__":
    main()

#! /usr/bin/env python

import asyncio
from asyncio import TimeoutError, wait_for

from fastapi import FastAPI, HTTPException
from jupyter_client.manager import AsyncKernelClient, AsyncKernelManager
from pydantic import BaseModel

app = FastAPI()

KERNELS = {}


class ExecutionRequest(BaseModel):
    chat_id: str
    code: list[str]


class ExecutionResult(BaseModel):
    outputs: list[str]


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
    print(request.chat_id)
    if request.chat_id not in KERNELS:
        raise HTTPException(
            status_code=400,
            detail=f"Execution environment not yet created for {request.chat_id}",
        )

    try:
        _, kc = KERNELS[request.chat_id]
        outputs: list[str] = []
        for line in request.code:
            output = await wait_for(
                execute_code(kc=kc, code=line),
                timeout=120,
            )
            outputs.append(output)

        print(outputs)
    except TimeoutError:
        raise HTTPException(status_code=400, detail="Code execution timed out")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    return ExecutionResult(outputs=outputs)


class EnvironmentCreationRequest(BaseModel):
    chat_id: str


class EnvironmentDeletionRequest(BaseModel):
    chat_id: str


@app.post("/environment/create")
async def create_kernel(request: EnvironmentCreationRequest):
    if request.chat_id not in KERNELS:
        KERNELS[request.chat_id] = await kernel_client()
    return


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


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)

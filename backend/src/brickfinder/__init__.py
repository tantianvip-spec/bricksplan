"""Hello-world placeholder for the brickfinder backend.

This module exists only to validate the CI → image → deploy pipeline.
It is replaced by the real FastAPI app in M1 Task 12.
"""
from fastapi import FastAPI

app = FastAPI(title="brickfinder", version="0.0.1")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/")
def root() -> dict[str, str]:
    return {"message": "brickfinder hello-world", "version": "0.0.1"}

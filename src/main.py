from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional

app = FastAPI(title="DevOps API", version="1.0.0")

items: dict[int, dict] = {}
next_id = 1


class Item(BaseModel):
    name: str
    description: Optional[str] = None


class ItemResponse(BaseModel):
    id: int
    name: str
    description: Optional[str] = None


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.get("/items", response_model=List[ItemResponse])
def list_items():
    return [{"id": k, **v} for k, v in items.items()]


@app.post("/items", response_model=ItemResponse, status_code=201)
def create_item(item: Item):
    global next_id
    items[next_id] = item.model_dump()
    created = {"id": next_id, **items[next_id]}
    next_id += 1
    return created


@app.get("/items/{item_id}", response_model=ItemResponse)
def get_item(item_id: int):
    if item_id not in items:
        raise HTTPException(status_code=404, detail="Item not found")
    return {"id": item_id, **items[item_id]}


@app.delete("/items/{item_id}", status_code=204)
def delete_item(item_id: int):
    if item_id not in items:
        raise HTTPException(status_code=404, detail="Item not found")
    del items[item_id]

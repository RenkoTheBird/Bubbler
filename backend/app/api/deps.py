from fastapi import Request

def getPool(request: Request):
    return request.app.state.pool
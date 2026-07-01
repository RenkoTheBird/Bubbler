'''
Since asynpg does not support vector types,
This function converts a list of floats to a string 
that can be used in a SQL query.

Used on embeddings.
'''

def to_pgvector(values: list[float]) -> str:
    return "[" + ",".join(str(v) for v in values) + "]"
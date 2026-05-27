import bcrypt

def hash_password(password: str):
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt())


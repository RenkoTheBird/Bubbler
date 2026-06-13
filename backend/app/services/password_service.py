import bcrypt

class PasswordService:
    def hash_password(password: str):
        return bcrypt.hashpw(password.encode(), bcrypt.gensalt())

    def check_password(pw: str, password: str):
        return bcrypt.checkpw(pw, password)


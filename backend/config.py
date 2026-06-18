import logging
from dotenv import load_dotenv
from os import getenv
from urllib.parse import quote_plus

logger = logging.getLogger(__name__)

load_dotenv()

env_vars = [
    "DATABASE",
    "DB_USER",
    "DATABASE_PASSWORD",
    "HOST",
    "PORT",
]

missing = [var for var in env_vars if getenv(var) is None]

if missing:
    raise SystemExit(f"Error: Missing enviroment variable/s: {missing}")

class EnvVars:

    def __init__(self):
        self.database = getenv("DATABASE")
        self.db_user = getenv("DB_USER")
        self.db_pass = getenv("DATABASE_PASSWORD")
        self.host = getenv("HOST")
        self.port = getenv("PORT")
        # helps format parse it properly 
        self.db_url = f"postgresql://{self.db_user}:{quote_plus(self.db_pass)}@{self.host}:{self.port}/{self.database}"
        logger.info("Environment variables loaded successfully")
        
my_env_vars = EnvVars()
class AuthService:
    def __init__(self, repo: AuthRepo):
        self.repo = repo

    def postLoginInfo(self):
        login = self.repo.postLoginInfo()
        return login # checks success

    def postRegistrationInfo(self):
        register = self.repo.postRegistrationInfo()
        # add new login info to database
        return register
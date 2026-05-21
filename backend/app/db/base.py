import psycopg2.pool

'''
TODO: replace user/pw with env variables later
'''

pool = psycopg2.pool.AbstractConnectionPool(1, 10, 
                                            user="REPLACE", 
                                            password="THIS TOO", 
                                            host="IP", 
                                            port="NUMBER", 
                                            database="NAME")


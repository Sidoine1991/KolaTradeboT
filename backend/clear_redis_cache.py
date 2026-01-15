import redis
import os

if __name__ == "__main__":
    redis_host = os.getenv('REDIS_HOST', 'localhost')
    redis_port = int(os.getenv('REDIS_PORT', 6379))
    redis_db = int(os.getenv('REDIS_DB', 0))
    r = redis.Redis(host=redis_host, port=redis_port, db=redis_db)
    
    print(f"Connexion à Redis {redis_host}:{redis_port} DB {redis_db}")
    r.flushdb()
    print("✅ Cache Redis vidé (flushdb)") 
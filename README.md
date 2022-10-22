# librephotos-semi-docker
 Almost dockerless librephotos

# About
Often it is (too) hard to install the [dockerless librephotos](https://github.com/LibrePhotos/librephotos-linux "Librephotos linux"). Software version mismatch on the host or other reasons gives installation / compilation errors.
Dockerized version of the librephotos uses too many container on the host systems **already running** nginx (or other reverse proxy), redis cache server, Postgresql database. From the original [librephotos-docker](https://github.com/LibrePhotos/librephotos-docker "Librephotos docker") containers
- proxy
- db
- frontend
- backend
- redis

it is enough just 2 of them: backend and frontend. All other services - database, caching, proxy - can use on the host machine or even the remote servers.
Questionable is even the **docker** proxy service in the fully dockerized librephotos version - librephotos can be accessed directly on the port 3000 without proxy.

## Pros
Semi-dockerized version of the librephotos advantages:
- use existing host / remote services. No duplications, system cleaner and lighter;
- easy to update.

## Cons
- installation for advances users, who's system already has required services or system administrator can install.

***

## How to
Stages
1. Modify docker-compose.yml and .env files
2. Create database and test connection
3. Install librephotos-semi-docker
4. Adopt nginx reverse proxy

### Stage 1 - modifying files
Download two files from official  [librephotos-docker](https://github.com/LibrePhotos/librephotos-docker "Librephotos docker"), or clone git repository , or rewrite letter by letter - that on you.
Clone git repository:
```
cd && git clone https://github.com/Seneliux/librephotos-semi-docker.git
cd
```
Delete services from the file _docker-compose.yml_ **only** if your host runs these services or can use remotely services like remote database server. Otherwise use docker version for these services.
test

#### REDIS server
```
redis:
    image: redis:6
    container_name: redis
    restart: unless-stopped
```
#### Postgresql database
```
db:
    image: postgres:13
    container_name: db
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${dbUser}
      - POSTGRES_PASSWORD=${dbPass}
      - POSTGRES_DB=${dbName}
    volumes:
      - ${data}/db:/var/lib/postgresql/data
    command: postgres -c fsync=off -c synchronous_commit=off -c full_page_writes=off -c random_page_cost=1.0
    #Checking health of Postgres db
    healthcheck:
      test: psql -U ${dbUser} -d ${dbName} -c "SELECT 1;"
      interval: 5s
      timeout: 5s
      retries: 5
```
**and**
```
# Wait for Postgres
    depends_on:
      db:
        condition: service_healthy
```
#### PROXY
```
proxy:
   image: reallibrephotos/librephotos-proxy:${tag}
   container_name: proxy
   restart: unless-stopped
   volumes:
     - ${scanDirectory}:/data
     - ${data}/protected_media:/protected_media
   ports:
     - ${httpPort}:80
   depends_on:
     - backend
     - frontend
```
Here are examples of the final [docker-compose.yml](../draft/docker-compose.yml) and [.env](../draft/.env) files. Changed or modified lines commented. Every else deleted.

### Stage 2 - Database
Configurations files examples is for the Postgresql **15** on Ubuntu system. Please adopt path, version to your system.
On the remote database server open port (default) 5432 and change configuration  `/etc/postgresql/15/main/postgresql.conf`. Of course, if server is remote. Do not forget to open port.
Change line:
`listen_addresses = '*'`

Add to the file `/etc/postgresql/15/main/pg_hba.conf` at the end this line, event if the database server is local:
```
host    all             all             0.0.0.0/0            md5
```

Connect to the database locally, or login to to the remote machine, and then connect to database from root account. **Do it copying line by line**, this is (not yet) automatized (sorry, I have no time). Two lines `DROP...` will **WIPE* old librephotos database and user, if exist. Useful for full reinstall, otherwise think twice. Password _AaAa1234_ must be the same in the file `.env`.

```
su postgres
psql
DROP DATABASE IF EXISTS librephotos;
DROP USER IF EXISTS librephotos;
CREATE USER librephotos;
CREATE DATABASE "librephotos" WITH OWNER "librephotos" TEMPLATE = template0 ENCODING = "UTF8";
GRANT ALL privileges ON DATABASE librephotos TO librephotos;
ALTER USER librephotos WITH PASSWORD 'AaAa1234';
EXIT
exit
```

Connect to database:

```
psql -h 111.222.333.444 -p 5432 -U librephotos
```
IP is the same like in the file _.env_ `dbHost=111.222.333.444`
Enter password, and if you see prompt 'librephotos=>' continue by typing "exit", otherwise make same caffe and find (legal) way to connect to the librephotos database as librephotos user.

### Stage 3 - installing librephotos-semi-docker
CD to the librephotos-semi-docker and run
```bash
docker-compose up -d
```
After few minutes test listening ports:
```bash
lsof -i:3000
lsof -i:8001
```
Must return some output like:
`docker-pr 1485590 root    4u  IPv4 2193053      0t0  TCP *:3000 (LISTEN)
docker-pr 1485645 root    4u  IPv4 2193074      0t0  TCP *:8001 (LISTEN)`
If output is empty, then make another cup of coffee. Something is wrong with server, not only with you.

### Stage 4 - reverse proxy nginx.

How to install and configure nginx, [walking ducks](https://duckduckgo.com/ "ungoogle - privacy is important!") can find explanations, [here is example of the nginx FQDN subdomain config](../blob/draft/nginx_FQDN.conf) + configured [free letsencrypt SSL certificate](https://letsencrypt.org/ "letsencrypt"), runing on the same machine as _backend_.

### Stage 5 - coffee time

Upload photos, scan and enjoy.

Some notes:
Connection to redis server through socks. Redis config:
```port 0 
unixsocket /run/redis/redis-server.sock  
unixsocketperm 770
```

In the file `docker-compose.yml` these lines expose host socket to docker and docker connects directly to redis socket on the Host:
```
- /run/redis/redis-server.sock:/run/redis/redis-server.sock
- REDIS_PATH=/run/redis/redis-server.sock
```


If redis server is listening on port (default 6379), then expose port to host:
`backend:
  volumes:
    ports:
    - 6379:6379
`
and socket- instead of REDIS_PATH add two lines:
`
environment:
  - REDIS_HOST=111.222.333.444   #CAHNGE IP
  - REDIS_PORT=6379
`

#### Update
The same way like [librephotos-docker](https://github.com/LibrePhotos/librephotos-docker "Librephotos docker").

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

it is enough just 2 of them: backend and frontend. All other services - database, caching, proxy - can use on the host machine or even on the remote servers.

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

Clone git repository:
```
cd && git clone https://github.com/Seneliux/librephotos-semi-docker.git
cd librephotos-semi-docker

```
In case of **NOT USING** some services on the host machine, copy these from upstream [librephotos-docker](https://github.com/LibrePhotos/librephotos-docker "Librephotos docker") github repository (here these are not updated). Accordinally change some variables in the fiel _.env_ , like _dbhost=db_ : 

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

### Stage 2 - Database
If librephotos uses docker database service, skip this step to [Stage 3 - installing librephotos-semi-docker](https://github.com/Seneliux/librephotos-semi-docker/edit/draft/README.md#stage-3---installing-librephotos-semi-docker).  
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
IP is the same like in the file _.env_ `dbHost=111.222.333.444`. On the local network under NAT IP can be local 192.168.0.0/24, on server, connected directly to internet, can be external IP. Check IP:
```
ip a
```


Enter password, and if you see prompt 'librephotos=>' continue by typing "exit", otherwise make same caffe and find (legal) way to connect to the librephotos database as librephotos user.
Show tables in the database:
```
\dt
```
For now must be empty. This will need later, if firewall does not allows connectiong between the docker container and host.

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

Run script 'nginx.sh', then copy file _librephotos_  to nginx virtual host directory (Ubuntu default is /etc/nginx/sites-available) and enable this host.

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
```
backend:
  volumes:
    ports:
    - 6379:6379
```
and socket- instead of REDIS_PATH (delete this line) add two new lines:
```
environment:
  - REDIS_HOST=111.222.333.444   #CAHNGE IP
  - REDIS_PORT=6379
```

#### Update
The same way like [librephotos-docker](https://github.com/LibrePhotos/librephotos-docker "Librephotos docker").

#### Issues
Affer installation, first screen in the browser must be User registrarion. If shows only login page, that can couse firewall. Check logs by greping Postgresql port (dfault 5432):
```
cat /var/log/ufw.log | grep 5432
```
If output gives lines about blocking, then must allow connection from librephotos **backend** to Host.
First at all must find docker network address and subnen. A few commands- first shows docker networks, second - shows network information ( the ID 05656707dfc7 is only example , change it to real docker network ID:
```
docker network ls
docker network inspect  05656707dfc7
```
Then find IPV4 and allow to connect:
```
 ufw allow from 172.18.0.0/16
```
Then restart librephotos, and try again to connect.

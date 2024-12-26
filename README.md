# docker-dashboard

## Architecture
This Docker Dashboard is comprised of all free and open source software and allows you to build your own container image to your liking. I have chosen to use an Alpine Linux container for housing a bash script that scrapes data from my docker hosts and then displays the data in an HTML table. You can then host this on a docker container host itself to have access to the simple web interface to see your containers.

## How to get started
Please check out my full blog post on the tool here and what each file does: https://www.virtualizationhowto.com/2024/12/docker-dashboard-new-tool-lets-you-see-containers-across-multiple-hosts/

The steps include
- Make sure you have a SSH keypair created and you can connect to your Docker hosts using this
- Create the files that are needed that are shown in the repo (you can clone the repo and just add your SSH key)
- Run the docker build command
- Run the docker run or docker compose command

```
docker build -t docker-dashboard .
```

## Docker run and Compose commands:

The docker run command:

```
docker run -d -p 8080:80 \
  -e CRON_SCHEDULE="*/5 * * * *" \
  -e TZ="America/New_York" \
  -e DOCKER_HOSTS="root@cldocker,root@cldocker01,root@cldocker02,root@cldockertest,root@cldockertest2,root@cldockertest3,root@clswarm01,root@clswarm02,root@clswarm03" \
  --name docker-dashboard \
  docker-dashboard
```
The docker compose code:
```
version: "3.8"

services:
  docker-dashboard:
    image: docker-dashboard
    container_name: docker-dashboard
    environment:
      - CRON_SCHEDULE=*/5 * * * *
      - DOCKER_HOSTS=root@cldocker,root@cldocker01
      - TZ=America/Chicago
    ports:
      - "8080:80"
    volumes:
      - ./data:/var/www/html
```

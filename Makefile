.PHONY: all test clean

KOHAENV ?= dev

ifdef NOVAGRANT
CMD=bash
KOHAPATH=$(shell pwd)
NOVAGRANT=true
HOST ?= localhost
DOCKER_GW=172.19.0.1
else
CMD=vagrant ssh $(SHIP)
KOHAPATH=/vagrant
HOST ?= 192.168.50.1
DOCKER_GW=$(HOST)
NOVAGRANT=false
endif

all: reload build run

reload: halt up provision

halt:
	@$(NOVAGRANT) || vagrant halt
	@$(NOVAGRANT) && sudo $(CMD) -c "cd $(KOHAPATH)/docker-compose && sudo docker-compose down" || true

up:                                              ##
	@$(NOVAGRANT) || vagrant up
	@$(NOVAGRANT) && sudo $(CMD) -c "cd $(KOHAPATH)/docker-compose && sudo docker-compose up -d" || true

shell_provision:					## Run ONLY shell provisioners
	@$(NOVAGRANT) || vagrant provision --provision-with shell
	-@$(NOVAGRANT) && ./provision.sh $(KOHAENV) $(KOHAPATH)

provision:  shell_provision   	## Full provision

wait_until_ready:
	@echo "=======    wait until ready    ======\n"
	$(CMD) -c 'sudo docker exec -t koha_docker ./wait_until_ready.py'

mysql: create_data_volume mysql_pull_if_missing mysql_start

# Data volume container for mysql - for persistent data. Create new if not existing
create_data_volume:
	@echo "======= CREATING MYSQL DATA VOLUME CONTAINER ======\n"
	@vagrant ssh -c '(sudo docker inspect mysql_data > /dev/null && echo "mysql data volume already present") || \
	docker run -d --name mysql_data -v /var/lib/mysql busybox echo "create data volume"'

mysql_pull_if_missing:
	@echo "Checking if there is an existing mysql image" ;\
	MYSQL_IMAGE=`vagrant ssh -c 'sudo docker images | grep "mysql " |  grep " 5.6 "'` ;\
	if [ "$$MYSQL_IMAGE" = "" ]; then \
		echo "no existing mysql image with correct tag ... pulling"; \
		vagrant ssh -c 'sudo docker pull mysql:5.6.20'; \
    fi

mysql_start:
	@ CURRENT_MYSQL_IMAGE=`vagrant ssh -c 'sudo docker inspect --format {{.Image}} koha_docker_mysql'` ;\
	LAST_MYSQL_IMAGE=`vagrant ssh -c 'sudo docker history --quiet --no-trunc mysql:5.6 | head -n 1'` ;\
	echo "Current image: $$CURRENT_MYSQL_IMAGE" ;\
	echo "Last image $$LAST_MYSQL_IMAGE" ;\
	if [ $$CURRENT_MYSQL_IMAGE = $$LAST_MYSQL_IMAGE ]; then \
		echo "mysql image up to date ... restarting"; \
		vagrant ssh -c 'sudo docker restart koha_docker_mysql '; \
	else \
		echo "restarting container from new image ..."; \
		vagrant ssh -c 'sudo docker stop koha_docker_mysql && sudo docker rm koha_docker_mysql'; \
		vagrant ssh -c 'sudo docker run -d --name koha_docker_mysql -p 3306:3306 --volumes-from mysql_data \
	  -e MYSQL_ROOT_PASSWORD=secret \
	  -e MYSQL_USER=admin \
	  -e MYSQL_PASSWORD=secret \
	  -e MYSQL_DATABASE=koha_name \
	  -t mysql:5.6.20 \
	  mysqld --datadir=/var/lib/mysql --user=mysql --max_allowed_packet=64M --wait_timeout=6000 --bind-address=0.0.0.0' ;\
	fi

mysql_stop:
	@echo "======= RESTARTING MYSQL CONTAINER ======\n"
	vagrant ssh -c '(sudo docker stop koha_docker_mysql && sudo docker rm koha_docker_mysql) || true'

gosmtp:	gosmtp_pull gosmtp_start

gosmtp_pull:
	vagrant ssh -c 'sudo docker pull digibib/gosmtpd:e51ec0b872867560461ab1e8c12b10fd63f5d3c1'

# for REAL forwarding, set env FORWARD_SMTP to receiving smtp service
gosmtp_start:
	@echo "restarting gosmtpd container  ..."; \
	vagrant ssh -c 'sudo docker stop gosmtp && sudo docker rm gosmtp'; \
	vagrant ssh -c 'sudo docker run -d --name gosmtp -p 8000:8000 \
		-e FORWARD_SMTP=$(FORWARD_SMTP) \
		-t digibib/gosmtpd:e51ec0b872867560461ab1e8c12b10fd63f5d3c1 ' ;\

gosms: gosms_pull gosms_start gosms_fake_listener

gosms_pull:
	vagrant ssh -c 'docker pull digibib/tcp-proxy:7660632e2afa09593941fd35ba09d6c3a948f342'

# Start a fake listener at local port 8102 inside container
gosms_fake_listener:
	vagrant ssh -c "docker exec -d gosms sh -c 'while true; do { echo -e \"HTTP/1.1 200 OK\r\n\"; } | nc -l -p 8102; done'"

# for REAL forwarding, set env SMS_FORWARD_URL to receiving sms http service at HOST:PORT
gosms_start:
	@echo "restarting gosms container  ..."; \
	vagrant ssh -c 'docker stop gosms && sudo docker rm gosms'; \
	vagrant ssh -c 'docker run -d --name gosms -p 8101:8101 \
		-t digibib/tcp-proxy:7660632e2afa09593941fd35ba09d6c3a948f342 \
		/app/tcp-proxy -l :8101 -vv -r $(SMS_FORWARD_URL)' ;\

build:
	@echo "======= BUILDING KOHA CONTAINER ======\n"
	vagrant ssh -c 'sudo docker build -t digibib/koha /vagrant '

build_debianfiles:
	@echo "======= BUILDING KOHA CONTAINER FROM LOCAL DEBIANFILES ======\n"
	vagrant ssh -c 'sudo docker build -f /vagrant/Dockerfile.debianfiles -t digibib/koha /vagrant '

stop: 
	@echo "======= STOPPING KOHA CONTAINER ======\n"
	vagrant ssh -c 'sudo docker stop koha_docker' || true

delete: stop
	@echo "======= DELETING KOHA CONTAINER ======\n"
	vagrant ssh -c 'sudo docker rm koha_docker' || true

KOHA_INSTANCE  ?= name
KOHA_ADMINUSER ?= admin
KOHA_ADMINPASS ?= secret

run: delete
	@echo "======= RUNNING KOHA CONTAINER WITH LOCAL MYSQL ======\n"
	@vagrant ssh -c 'sudo docker run -d --name koha_docker \
	-p 80:80 -p 6001:6001 -p 8080:8080 -p 8081:8081 \
	-e KOHA_INSTANCE=$(KOHA_INSTANCE) \
	-e KOHA_ADMINUSER=$(KOHA_ADMINUSER) \
	-e KOHA_ADMINPASS=$(KOHA_ADMINPASS) \
	-e DEFAULT_LANGUAGE="$(DEFAULT_LANGUAGE)" \
    -e INSTALL_LANGUAGES="$(INSTALL_LANGUAGES)" \
	--cap-add=SYS_NICE --cap-add=DAC_READ_SEARCH \
	-t digibib/koha' || echo "koha_docker container already running, please 'make delete' first"

EMAIL_ENABLED ?= true
SMTP_SERVER_HOST ?= mailrelay
SMTP_SERVER_PORT ?= 2525
MESSAGE_QUEUE_FREQUENCY ?= 1
SMS_SERVER_HOST ?= http://localhost:8101
SMS_FORWARD_URL ?= :8102

run_with_messaging: gosmtp gosms delete
	@echo "======= RUNNING KOHA CONTAINER WITH LOCAL MYSQL AND MESSAGING ======\n"
	@vagrant ssh -c 'sudo docker run --link gosmtp:mailrelay --link gosms:smsproxy -d --name koha_docker \
	-p 80:80 -p 6001:6001 -p 8080:8080 -p 8081:8081 \
	-e KOHA_INSTANCE=$(KOHA_INSTANCE) \
	-e KOHA_ADMINUSER=$(KOHA_ADMINUSER) \
	-e KOHA_ADMINPASS=$(KOHA_ADMINPASS) \
	-e DEFAULT_LANGUAGE="$(DEFAULT_LANGUAGE)" \
    -e INSTALL_LANGUAGES="$(INSTALL_LANGUAGES)" \
    -e EMAIL_ENABLED="$(EMAIL_ENABLED)" \
    -e SMTP_SERVER_HOST="$(SMTP_SERVER_HOST)" \
    -e SMTP_SERVER_PORT="$(SMTP_SERVER_PORT)" \
    -e MESSAGE_QUEUE_FREQUENCY="$(MESSAGE_QUEUE_FREQUENCY)" \
    -e SMS_SERVER_HOST="$(SMS_SERVER_HOST)" \
    -e SMS_FORWARD_URL="$(SMS_FORWARD_URL)" \
	--cap-add=SYS_NICE --cap-add=DAC_READ_SEARCH \
	-t digibib/koha' || echo "koha_docker container already running, please 'make delete' first"

# start koha with link to mysql container
run_linked_db: mysql delete
	@echo "======= RUNNING KOHA CONTAINER WITH MYSQL FROM LINKED DB CONTAINER ======\n"
	@vagrant ssh -c 'sudo docker run --link koha_docker_mysql:koha_mysql -d --name koha_docker \
	-p 80:80 -p 6001:6001 -p 8080:8080 -p 8081:8081 \
	-e KOHA_INSTANCE=$(KOHA_INSTANCE) \
	-e KOHA_ADMINUSER=$(KOHA_ADMINUSER) \
	-e KOHA_ADMINPASS=$(KOHA_ADMINPASS) \
	-e DEFAULT_LANGUAGE="$(DEFAULT_LANGUAGE)" \
    -e INSTALL_LANGUAGES="$(INSTALL_LANGUAGES)" \
	-t digibib/koha' || echo "koha_docker container already running, please 'make delete' first"

logs:
	vagrant ssh -c 'sudo docker logs koha_docker'

logs-f:
	vagrant ssh -c 'sudo docker logs -f koha_docker'

nsenter:
	vagrant ssh -c 'sudo docker exec -it koha_docker /bin/bash'

browser:
	vagrant ssh -c 'firefox "http://localhost:8081/" > firefox.log 2> firefox.err < /dev/null' &


test: wait_until_ready
	@echo "======= TESTING KOHA CONTAINER ======\n"

clean:
	vagrant destroy --force

login: # needs EMAIL, PASSWORD, USERNAME
	@ vagrant ssh -c 'sudo docker login --email=$(EMAIL) --username=$(USERNAME) --password=$(PASSWORD)'

tag = "$(shell git rev-parse HEAD)"

tag:
	vagrant ssh -c 'sudo docker tag -f digibib/koha digibib/koha:$(tag)'

push: tag
	@echo "======= PUSHING KOHA CONTAINER ======\n"
	vagrant ssh -c 'sudo docker push digibib/koha'

docker_cleanup:
	@echo "cleaning up unused containers and images"
	@vagrant ssh -c 'sudo /vagrant/docker-cleanup.sh'

# How to:
# Run the rest tests in Jenkins: make -C tuleap BUILD_ENV=ci ci_api_test
# Run the phpunit tests in Jenkins: make -C tuleap BUILD_ENV=ci ci_phpunit
# Run docker as a priviledged user: make SUDO=sudo ... or make SUDO=pkexec ...

OS := $(shell uname)
ifeq ($(OS),Darwin)
DOCKER_COMPOSE_FILE=-f docker-compose.yml -f docker-compose-mac.yml
else
DOCKER_COMPOSE_FILE=-f docker-compose.yml
endif

SUDO=
DOCKER=$(SUDO) docker
DOCKER_COMPOSE=$(SUDO) docker-compose $(DOCKER_COMPOSE_FILE)

AUTOLOAD_EXCLUDES=^tests|^template

.DEFAULT_GOAL := help

help:
	@grep -E '^[a-zA-Z0-9_-\ ]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
	@echo "(Other less used targets are available, open Makefile for details)"

#
# Utilities
#

doc: ## Build CLI documentation
	$(MAKE) -C documentation all

autoload:
	@echo "Generate core"
	@(cd src/common; phpab -q --compat -o autoload.php --exclude "./wiki/phpwiki/*" .)
	@for path in `ls src/www/themes | egrep -v "^Tuleap|^common|^FlamingParrot|^local"`; do \
	     echo "Generate theme $$path"; \
	     (cd "src/www/themes/$$path/"; phpab -q --compat -o autoload.php .) \
        done;
	@echo "Generate tests"
	@(cd tests/lib; phpab  -q --compat -o autoload.php .)
	@(cd tests/soap/lib; phpab  -q --compat -o autoload.php .)
	@(cd tests/rest/lib; phpab  -q --compat -o autoload.php .)
	@for path in `ls plugins | egrep -v "$(AUTOLOAD_EXCLUDES)"`; do \
		test -f "plugins/$$path/composer.json" && continue; \
		echo "Generate plugin $$path"; \
		(cd "plugins/$$path/include"; phpab -q --compat -o autoload.php $$(cat phpab-options.txt 2> /dev/null) .) \
        done;

autoload-with-userid:
	@echo "Generate core"
	@(cd src/common; phpab -q --compat -o autoload.php --exclude "./wiki/phpwiki/*" .;chown $(USER_ID):$(USER_ID) autoload.php)
	@echo "Generate tests"
	@(cd tests/lib; phpab  -q --compat -o autoload.php .;chown $(USER_ID):$(USER_ID) autoload.php)
	@(cd tests/soap/lib; phpab  -q --compat -o autoload.php .)
	@(cd tests/rest/lib; phpab  -q --compat -o autoload.php .)
	@for path in `ls plugins | egrep -v "$(AUTOLOAD_EXCLUDES)"`; do \
		test -f "plugins/$$path/composer.json" && continue; \
		echo "Generate plugin $$path"; \
		(cd "plugins/$$path/include"; phpab -q --compat -o autoload.php $$(cat phpab-options.txt 2> /dev/null) .; chown $(USER_ID):$(USER_ID) autoload.php) \
        done;

autoload-docker: ## Generate autoload files
	@$(DOCKER) run --rm=true -v $(CURDIR):/tuleap -e USER=`id -u` -e GROUP=`id -g` enalean/tuleap-dev-swissarmyknife:2 --autoload

autoload-dev:
	@tools/utils/autoload.sh

.PHONY: composer
composer:  ## Install PHP dependencies with Composer
	@echo "Processing src/composer.json"
	@composer install --working-dir=src/
	@find plugins/ -mindepth 2 -maxdepth 2 -type f -name 'composer.json' \
		-exec echo "Processing {}" \; -execdir composer install \;

## RNG generation

rnc2rng-docker: clean-rng ## Compile rnc file into rng
	@$(DOCKER) run --rm=true -v $(CURDIR):/tuleap -e USER=`id -u` -e GROUP=`id -g` enalean/tuleap-dev-swissarmyknife:2 --rnc2rng

rnc2rng: src/common/xml/resources/project/project.rng \
	 src/common/xml/resources/users.rng  \
	 plugins/svn/resources/svn.rng \
	 src/common/xml/resources/ugroups.rng \
	 plugins/tracker/www/resources/tracker.rng \
	 plugins/tracker/www/resources/trackers.rng \
	 plugins/tracker/www/resources/artifacts.rng \
	 plugins/agiledashboard/www/resources/xml_project_agiledashboard.rng \
	 plugins/cardwall/www/resources/xml_project_cardwall.rng

src/common/xml/resources/project/project.rng: src/common/xml/resources/project/project.rnc plugins/tracker/www/resources/tracker-definition.rnc src/common/xml/resources/ugroups-definition.rnc plugins/svn/resources/svn-definition.rnc src/common/xml/resources/frs-definition.rnc src/common/xml/resources/mediawiki-definition.rnc src/common/xml/resources/project-definition.rnc

plugins/svn/resources/svn.rng: plugins/svn/resources/svn.rnc plugins/svn/resources/svn-definition.rnc

src/common/xml/resources/ugroups.rng: src/common/xml/resources/ugroups.rnc src/common/xml/resources/ugroups-definition.rnc

plugins/tracker/www/resources/trackers.rng: plugins/tracker/www/resources/trackers.rnc plugins/tracker/www/resources/tracker-definition.rnc plugins/tracker/www/resources/artifact-definition.rnc plugins/tracker/www/resources/triggers.rnc

plugins/tracker/www/resources/tracker.rng: plugins/tracker/www/resources/tracker.rnc plugins/tracker/www/resources/tracker-definition.rng

plugins/tracker/www/resources/artifacts.rng: plugins/tracker/www/resources/artifacts.rnc plugins/tracker/www/resources/artifact-definition.rng

%.rng: %.rnc
	trang -I rnc -O rng $< $@

clean-rng:
	find . -type f -name "*.rng" | xargs rm -f

#
# Tests and all
#

post-checkout: composer generate-mo dev-clear-cache dev-forgeupgrade npm-build restart-services ## Clear caches, run forgeupgrade, build assets and generate language files

npm-build:
	npm install
	npm run build

redeploy-nginx: ## Redeploy nginx configuration
	@$(DOCKER) exec tuleap-web /usr/share/tuleap/tools/utils/php56/run.php --module=nginx
	@$(DOCKER) exec tuleap-web service nginx restart

restart-services: redeploy-nginx ## Restart nginx, apache and fpm
	@$(DOCKER) exec tuleap-web service rh-php56-php-fpm restart
	@$(DOCKER) exec tuleap-web service httpd restart

generate-po: ## Generate translatable strings
	@tools/utils/generate-po.php `pwd`

generate-mo: ## Compile tranlated strings into binary format
	@tools/utils/generate-mo.sh `pwd`

tests_rest: ## Run all REST tests
	$(DOCKER) run -ti --rm -v $(CURDIR):/usr/share/tuleap --mount type=tmpfs,destination=/tmp enalean/tuleap-test-rest:c6-php56-httpd24-mysql56

tests_soap: ## Run all SOAP tests
	$(DOCKER) run -ti --rm -v $(CURDIR):/usr/share/tuleap --mount type=tmpfs,destination=/tmp enalean/tuleap-test-soap:3

tests_rest_setup: ## Start REST tests container to launch tests manually
	$(DOCKER) run -ti --rm -v $(CURDIR):/usr/share/tuleap --mount type=tmpfs,destination=/tmp -w /usr/share/tuleap enalean/tuleap-test-rest:c6-php56-httpd24-mysql56 bash

phpunit-ci-run:
	$(PHP) src/vendor/bin/phpunit \
		-c tests/phpunit/phpunit.xml \
		--log-junit /tmp/results/phpunit_tests_results.xml \
		--coverage-html /tmp/results/phpunit_coverage \
		--coverage-clover /tmp/results/phpunit_coverage/coverage.xml

run-as-owner:
	@USER_ID=`stat -c '%u' /tuleap`; \
	GROUP_ID=`stat -c '%g' /tuleap`; \
	groupadd -g $$GROUP_ID runner; \
	useradd -u $$USER_ID -g $$GROUP_ID runner
	su -c "$(MAKE) -C $(CURDIR) $(TARGET) PHP=$(PHP)" -l runner

phpunit-ci-56:
	mkdir -p $(WORKSPACE)/results/ut-phpunit-php-56
	@docker run --rm -v $(CURDIR):/tuleap:ro -v $(WORKSPACE)/results/ut-phpunit-php-56:/tmp/results --entrypoint /bin/bash enalean/tuleap-test-phpunit:c6-php56 -c "make -C /tuleap run-as-owner TARGET=phpunit-ci-run PHP=/opt/rh/rh-php56/root/usr/bin/php"

phpunit-ci-70:
	mkdir -p $(WORKSPACE)/results/ut-phpunit-php-70
	@docker run --rm -v $(CURDIR):/tuleap:ro -v $(WORKSPACE)/results/ut-phpunit-php-70:/tmp/results enalean/tuleap-test-phpunit:c6-php70 make -C /tuleap TARGET=phpunit-ci-run PHP=/opt/rh/rh-php70/root/usr/bin/php run-as-owner

phpunit-docker-56:
	@docker run --rm -v $(CURDIR):/tuleap:ro enalean/tuleap-test-phpunit:c6-php56 scl enable rh-php56 "make -C /tuleap phpunit"

phpunit-docker-70:
	@docker run --rm -v $(CURDIR):/tuleap:ro enalean/tuleap-test-phpunit:c6-php70 scl enable rh-php70 "make -C /tuleap phpunit"

phpunit:
	src/vendor/bin/phpunit -c tests/phpunit/phpunit.xml

deploy-githooks:
	@if [ -e .git/hooks/pre-commit ]; then\
		echo "pre-commit hook already exists";\
	else\
		hash phpcs 2>/dev/null && {\
			echo "Creating pre-commit hook";\
			ln -s ../../tools/utils/githooks/hook-chain .git/hooks/pre-commit;\
		} || {\
			echo "You need to install phpcs before.";\
			echo "For example on a debian-based environment:";\
			echo "  sudo apt-get install php-pear";\
			echo "  sudo pear install PHP_CodeSniffer";\
			exit 1;\
		};\
	fi

#
# Start development enviromnent with Docker Compose
#

dev-setup: .env deploy-githooks ## Setup environment for Docker Compose (should only be run once)

.env:
	@echo "MYSQL_ROOT_PASSWORD=`env LC_CTYPE=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32`" > .env
	@echo "LDAP_ROOT_PASSWORD=`env LC_CTYPE=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32`" >> .env
	@echo "LDAP_MANAGER_PASSWORD=`env LC_CTYPE=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32`" >> .env
	@echo "RABBITMQ_DEFAULT_PASS=`env LC_CTYPE=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32`" >> .env
	@echo RABBITMQ_DEFAULT_USER=tuleap >> .env
	@echo VIRTUAL_HOST=tuleap-web.tuleap-aio-dev.docker >> .env

show-passwords: ## Display passwords generated for Docker Compose environment
	@$(DOCKER_COMPOSE) exec web cat /data/root/.tuleap_passwd

dev-forgeupgrade: ## Run forgeupgrade in Docker Compose environment
	@$(DOCKER) exec tuleap-web /usr/lib/forgeupgrade/bin/forgeupgrade --config=/etc/tuleap/forgeupgrade/config.ini update

dev-clear-cache: ## Clear caches in Docker Compose environment
	@$(DOCKER) exec tuleap-web /usr/share/tuleap/src/utils/tuleap --clear-caches

start-php56 start: ## Start Tuleap web with php56 & nginx
	@echo "Start Tuleap in PHP 5.6"
	@./tools/docker/migrate_to_volume.sh
	@$(DOCKER_COMPOSE) -f docker-compose.yml up -d web
	@echo -n "tuleap-web ip address: "
	@$(DOCKER) inspect -f '{{.NetworkSettings.Networks.tuleap_default.IPAddress}}' tuleap-web

start-distlp:
	@echo "Start Tuleap with reverse-proxy, backend web and backend svn"
	@./tools/docker/migrate_to_volume.sh
	-@$(DOCKER_COMPOSE) stop
	@$(DOCKER_COMPOSE) -f docker-compose-distlp.yml up -d reverse-proxy
	@ip=`$(DOCKER) inspect -f '{{.NetworkSettings.Networks.tuleap_default.IPAddress}}' tuleap_reverse-proxy_1`; \
		echo "Add '$$ip tuleap-web.tuleap-aio-dev.docker' to /etc/hosts"; \
		echo "Ensure $$ip is configured as sys_trusted_proxies in /etc/tuleap/conf/local.inc"
	@echo "You can access :"
	@echo "* Reverse proxy with: docker exec -ti tuleap_reverse-proxy_1 bash"
	@echo "* Backend web with: docker exec -ti tuleap_backend-web_1 bash"
	@echo "* Backend SVN with: docker exec -ti tuleap_backend-svn_1 bash"

stop-distlp:
	@$(SUDO) docker-compose -f docker-compose-distlp.yml stop

env-gerrit: .env
	@grep --quiet GERRIT_SERVER_NAME .env || echo 'GERRIT_SERVER_NAME=tuleap-gerrit.gerrit-tuleap.docker' >> .env

start-gerrit: env-gerrit
	@docker-compose up -d gerrit
	@echo "Gerrit will be available soon at http://`grep GERRIT_SERVER_NAME .env | cut -d= -f2`:8080"

start-all:
	echo "Start all containers (Web, LDAP, DB, Elasticsearch)"
	@$(DOCKER_COMPOSE) up -d

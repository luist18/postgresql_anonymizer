##
## This Makefile is trying to mimic the targets and behaviour of the
## PGXS Makefile
##
## see https://github.com/postgres/postgres/blob/master/src/makefiles/pgxs.mk
##

PGRX?=cargo pgrx
PGVER?=$(shell grep 'default = \[".*\"]' Cargo.toml | sed -e 's/.*\["//' | sed -e 's/"].*//')
PG_MAJOR_VERSION=$(PGVER:pg%=%)

# use `TARGET=debug make run` for more detailed errors
TARGET?=release
TARGET_DIR?=target/$(TARGET)/anon-$(PGVER)/
PG_CONFIG?=`$(PGRX) info pg-config $(PGVER) 2> /dev/null || echo pg_config`
PG_SHAREDIR?=$(shell $(PG_CONFIG) --sharedir)
PG_LIBDIR?=$(shell $(PG_CONFIG) --libdir)
PG_BINDIR?=$(shell $(PG_CONFIG) --bindir)

# Be sure to use the PGRX version (PGVER) of the postgres binaries
# It's especially important for the pg_dump test in pg_regress
PATH:=$(PG_BINDIR):${PATH}

# This is where the package is placed
TARGET_SHAREDIR?=$(TARGET_DIR)/$(PG_SHAREDIR)
TARGET_LIBDIR?=$(TARGET_DIR)/$(PG_LIBDIR)

PG_REGRESS?=$(PG_LIBDIR)/pgxs/src/test/regress/pg_regress
PG_SOCKET_DIR?=/var/lib/postgresql/.pgrx/
PGHOST?=localhost
PGPORT?=288$(subst pg,,$(PGVER))
PSQL_OPT?=--host $(PGHOST) --port $(PGPORT)
PGDATABASE?=contrib_regression

##
## PGXS tests
##

# PGXS is used only for functional testing with `make installcheck`
# For unit tests, we use `cargo` via `make test`

REGRESS_TESTS = init
REGRESS_TESTS+= ternary
REGRESS_TESTS+= noise shuffle
REGRESS_TESTS+= detection
REGRESS_TESTS+= get_function_schema trusted_schemas
REGRESS_TESTS+= copy pg_dump
REGRESS_TESTS+= masking_expressions
REGRESS_TESTS+= sampling
REGRESS_TESTS+= destruction random dummy faking partial
REGRESS_TESTS+= pseudonymization hashing
REGRESS_TESTS+= ldm transparent_dynamic_masking
REGRESS_TESTS+= anon_catalog anonymize privacy_by_default
REGRESS_TESTS+= multiple_masking_policies
#REGRESS_TESTS+= restore
REGRESS_TESTS+= hasmask masked_roles masking masking_search_path masking_foreign_tables
REGRESS_TESTS+= generalization k_anonymity
REGRESS_TESTS+= permissions_owner permissions_masked_role injection syntax_checks
REGRESS_TESTS+= views elevation_via_mask

# We try our best to write tests that produce the same output on all the 5
# current Postgres major versions. But sometimes it's really hard to do and
# we generally prefer simplicity over complex output manipulation tricks.
#
# In these few special cases, we use conditional tests with the following
# naming rules:
# * the _PG15+ suffix means PostgreSQL 15 and all the major versions after
# * the _PG13- suffix means PostgreSQL 13 and all the major versions below

REGRESS_TESTS_PG12 = elevation_via_rule_PG15-
REGRESS_TESTS_PG13 = elevation_via_rule_PG15-
REGRESS_TESTS_PG14 = elevation_via_rule_PG15-
REGRESS_TESTS_PG15 = elevation_via_rule_PG15-
REGRESS_TESTS_PG16 =
REGRESS_TESTS_PG17 =

REGRESS_TESTS+=${REGRESS_TESTS_PG${PG_MAJOR_VERSION}}

# Use this var to add more tests
#PG_TEST_EXTRA ?= ""
REGRESS_TESTS+=$(PG_TEST_EXTRA)

# This can be overridden by an env variable
REGRESS?=$(REGRESS_TESTS)


EXTRA_CLEAN?=target

##
## BUILD
##

all: extension

extension:
	$(PGRX) package --pg-config $(PG_CONFIG)
	mkdir -p $(TARGET_SHAREDIR)/extension/anon/
	install data/*.csv $(TARGET_SHAREDIR)/extension/anon/
	install data/en_US/fake/*.csv $(TARGET_SHAREDIR)/extension/anon/


##
## INSTALL
##

install:
	cp -r $(TARGET_SHAREDIR)/extension/* $(PG_SHAREDIR)/extension/
	install $(TARGET_LIBDIR)/anon.so $(PG_LIBDIR)

##
## INSTALLCHECK
##
## These are the functional tests, the unit tests are run with Cargo
##

installcheck:
	dropdb $(PSQL_OPT) --if-exists $(PGDATABASE)
	createdb $(PSQL_OPT) $(PGDATABASE)
	psql $(PSQL_OPT) $(PGDATABASE) -c "ALTER DATABASE $(PGDATABASE) SET session_preload_libraries = 'anon';"
	psql $(PSQL_OPT) $(PGDATABASE) -c "ALTER DATABASE $(PGDATABASE) SET anon.masking_policies = 'devtests, analytics';"
	$(PG_REGRESS) \
		$(PSQL_OPT) \
		--use-existing \
		--inputdir=./tests/ \
		--dbname=$(PGDATABASE) \
		$(REGRESS_OPTS) \
		$(REGRESS)


##
## PGRX commands
##

ifeq ($(TARGET),release)
  RELEASE_OPT=--release
endif

test:
	$(PGRX) test $(PGVER) $(RELEASE_OPT) --verbose

start:
	$(PGRX) start $(PGVER)

stop:
	$(PGRX) stop $(PGVER)

run:
	$(PGRX) run $(PGVER) $(RELEASE_OPT)

psql:
	psql --host localhost --port 288$(PG_MAJOR_VERSION)

##
## C L E A N
##

clean:
ifdef EXTRA_CLEAN
	rm -rf $(EXTRA_CLEAN)
endif


##
## All targets below are not part of the PGXS Makefile
##

##
## P A C K A G E S
##

rpm deb: package
	export PG_LIBDIR=.$(PG_LIBDIR) && \
	export PG_SHAREDIR=.$(PG_SHAREDIR) && \
	export PG_MAJOR_VERSION=$(PG_MAJOR_VERSION) && \
	envsubst < nfpm.template.yaml > $(TARGET_DIR)/nfpm.yaml
	cd $(TARGET_DIR) && nfpm package --packager $@


# The `package` command needs pg_config from the target version
# https://github.com/pgcentralfoundation/pgrx/issues/288

package:
	$(PGRX) package --pg-config $(PG_CONFIG)

##
## D O C K E R
##

DOCKER_IMAGE?=registry.gitlab.com/dalibo/postgresql_anonymizer
PGRX_IMAGE?=$(DOCKER_IMAGE):pgrx
PGRX_BUILD_ARGS?=

ifneq ($(PG_MAJOR_VERSION),)
BUILD_ARG := --build-arg PG_MAJOR_VERSION=$(PG_MAJOR_VERSION)
endif

docker_image: docker/Dockerfile #: build the docker image
	docker build --tag $(DOCKER_IMAGE) . --file $^  $(BUILD_ARG)

pgrx_image: docker/pgrx/Dockerfile
	docker build --tag $(PGRX_IMAGE) . --file $^ $(PGRX_BUILD_ARGS)

docker_push: #: push the docker image to the registry
	docker push $(DOCKER_IMAGE)

pgrx_push:
	docker push $(PGRX_IMAGE)

docker_bash: #: enter the docker image (useful for testing)
	docker exec -it docker-PostgreSQL-1 bash

pgrx_bash:
	docker run --rm --interactive --tty --volume  `pwd`:/pgrx $(PGRX_IMAGE)

COMPOSE=docker compose --file docker/docker-compose.yml

docker_init: #: start a docker container
	$(COMPOSE) down
	$(COMPOSE) up -d
	@echo "The Postgres server may take a few seconds to start. Please wait."

##
## L I N T
##

lint:
	cargo clippy

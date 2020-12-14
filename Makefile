include common.mk

CB := $(shell git branch --show-current)

all:
	@echo "no default make rule defined"

# Procedure:
# - run make release_X command
# - this will look for environment.X
# - if found, source it and run make deploy

release_main:
	@echo "Releasing current branch $(CB) to main"
	scripts/release.sh $(CB) main

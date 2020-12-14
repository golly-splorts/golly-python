SHELL=/bin/bash

ifeq ($(shell echo ${GOLLY_API_HOME}),)
$(error Environment variable GOLLY_API_HOME not defined. Please run "source environment" in the golly-api repo root directory before running make commands)
endif

#ifeq ($(shell which jq),)
#$(error Please install jq using "apt-get install jq" or "brew install jq")
#endif


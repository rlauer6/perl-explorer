#-*- mode: gnumakefile; -* -

PERL5LIB = "-I $${HOME}/lib/perl5 -I lib"

PERLMODULES = \
    Apache/Devel/Explorer.pm \
    Devel/Explorer.pm \
    Devel/Explorer/Utils.pm \
    Devel/Explorer/Source.pm \
    Devel/Explorer/Critic.pm \
    Devel/Explorer/PodWriter.pm \
    Devel/Explorer/Tidy.pm \
    Devel/Explorer/ToDo.pm

CSS = \
    perl-explorer.css \
    perl-explorer-common.css \
    perl-explorer-source.css \
    perl-explorer-pod.css \
    perl-explorer-critic.css

JS = \
   perl-explorer.js \
   perl-explorer-common.js \
   perl-explorer-critic.js \
   perl-explorer-source.js \


TEMPLATES = \
   perl-explorer.html

CONFIG = \
   perl-explorer.json

# set your BASE_DIR to the path where your Perl modules live
BASE_DIR = "$${HOME:-$(HOME)}/git/perl-explorer"

CSS_DIR = "$${CSS_DIR:-css}"

JS_DIR = "$${JS_DIR:-js}"

MODULES_DIR = "$${MODULES_DIR:-lib}"

TEMPLATES_DIR = 

CONFIG_DIR =


.PHONY: check

check:
	for a in $(PERLMODULES); do \
	  perl -wc "$(PERL5LIB)" "lib/$$a"; \
	done

.PHONY: install
install: check
	js_dir="$(JS_DIR)"; \
	css_dir="$(CSS_DIR)"; \
	base_dir="$(BASE_DIR)"; \
	config_dir="$(CONFIG_DIR)"; \
	modules_dir="$(MODULES_DIR)"; \
	templates_dir="$(TEMPLATES_DIR)";\
	echo "       JS_DIR: $$js_dir"; \
	echo "      CSS_DIR: $$css_dir"; \
	echo "   CONFIG_DIR: $$config_dir"; \
        echo "     BASE_DIR: $$base_dir"; \
	echo "  MODULES_DIR: $$modules_dir"; \
	echo "TEMPLATES_DIR: $$templates_dir"; \
	for a in $(PERLMODULES); do \
	  install -D lib/$$a $$base_dir/$$modules_dir/$$a; \
	done; \
	for a in $(CSS); do \
	  install -D css/$$a $$base_dir/$$css_dir/$$a; \
	done; \
	for a in $(JS); do \
	  install -D js/$$a $$base_dir/$$js_dir/$$a; \
	done; \
	for a in $(TEMPLATES); do \
	  install -D html/$$a $$base_dir/$$templates_dir/$$a; \
	done; \
	for a in $(CONFIG); do \
	  install -D $$a $$base_dir/$$config_dir/$$a; \
	done

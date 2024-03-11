#-*- mode: gnumakefile; -* -

PERL5LIB = "-I $${HOME}/lib/perl5 -I lib"

PERLMODULES = \
    Apache/Devel/Explorer.pm \
    Devel/Explorer.pm \
    Devel/Explorer/Base.pm \
    Devel/Explorer/Utils.pm \
    Devel/Explorer/Source.pm \
    Devel/Explorer/Critic.pm \
    Devel/Explorer/PodWriter.pm \
    Devel/Explorer/Tidy.pm \
    Devel/Explorer/ToDo.pm

HTTPD = \
    httpd.conf \
    perl-explorer.conf

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

IMAGES = \
   perl-logo.png

TEMPLATES = \
   perl-explorer-index.html.tt

CONFIG = \
   perl-explorer.json

RESOURCES = \
   .perlcriticrc \
   .perltidyrc \
   stop_words

# set your BASE_DIR to the path where your Perl modules live
BASE_DIR = "$${HOME:-$(HOME)}/git/perl-explorer/docker"

CSS_DIR = "$${CSS_DIR:-css}"

JS_DIR = "$${JS_DIR:-js}"

IMG_DIR = "$${IMG_DIR:-img}"

MODULES_DIR = "$${MODULES_DIR:-lib/perl5}"

TEMPLATES_DIR = "$${TEMPLATES_DIR:-resources}"

CONFIG_DIR = "$${CONFIG_DIR:-config}"

RESOURCES_DIR = "$${RESOURCES_DIR:-resources}"

HTTPD_DIR = "$${HTTPD_DIR:-httpd}"

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
	resources_dir="$(RESOURCES_DIR)"; \
	httpd_dir="$(HTTPD_DIR)"; \
	img_dir="$(IMG_DIR)"; \
	modules_dir="$(MODULES_DIR)"; \
	templates_dir="$(TEMPLATES_DIR)";\
	echo "       JS_DIR: $$js_dir"; \
	echo "      CSS_DIR: $$css_dir"; \
	echo "   CONFIG_DIR: $$config_dir"; \
	echo "   RESOURCES_DIR: $$resources_dir"; \
	echo "    HTTPD_DIR: $$httpd_dir"; \
	echo "      IMG_DIR: $$img_dir"; \
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
	  install -D templates/$$a $$base_dir/$$templates_dir/$$a; \
	done; \
	for a in $(CONFIG); do \
	  install -D $$a $$base_dir/$$config_dir/$$a; \
	done; \
	for a in $(RESOURCES); do \
	  install -D $$a $$base_dir/$$resources_dir/$$a; \
	done; \
	for a in $(IMAGES); do \
	  install -D img/$$a $$base_dir/$$img_dir/$$a; \
	done; \
	for a in $(HTTPD); do \
	  install -D httpd/$$a $$base_dir/$$httpd_dir/$$a; \
	done

.PHONY: clean
clean:
	for a in lib config js css img httpd resources; do \
	  files=$$(find docker/$$a -type f); \
	  test -n "$$files" && rm $$files || true; \
	done

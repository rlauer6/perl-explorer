#-*- mode: gnumakefile; -*-

APP = perl-explorer

$(APP): perl-base requires
	docker build $$NO_CACHE -f Dockerfile . -t perl-explorer 2>&1 | tee -a $@

perl-base: packages requires.base requires.extras
	docker build $NO_CACHE -f Dockerfile.perl . -t perl-base 2>&1 | tee -a $@

.PHONY: clean

clean:
	rm -f $(APP) perl-base

realclean: clean
	docker rmi $(APP)

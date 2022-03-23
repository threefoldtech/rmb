.PHONY : build
build:
	cd msgbusd && v -cg -gc boehm msgbusd.v

build-prod:
	cd msgbusd && v -gc boehm msgbusd.v

install-dependencies:
	git clone https://github.com/threefoldtech/vgrid $$HOME/.vmodules/threefoldtech/vgrid
	git clone https://github.com/crystaluniverse/crystallib $$HOME/.vmodules/despiegk/crystallib

update:
	v up && v update

install: build-prod
	sudo cp msgbusd/msgbusd /usr/local/bin

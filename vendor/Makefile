# You probably just want the 'all' target.
.PHONY: all
all: unzip verify headers

.PHONY: unzip
unzip:
	./unzip.sh

lib/libguile-3.0.a: big_sur/guile/3.0.7_2/lib/libguile-3.0.a arm64_big_sur/guile/3.0.7_2/lib/libguile-3.0.a
	mkdir -p $(@D)
	lipo -create $^ -output $@
	lipo $@ -archs

lib/libgc.a: arm64_big_sur/bdw-gc/8.0.6/lib/libgc.a big_sur/bdw-gc/8.0.6/lib/libgc.a
	mkdir -p $(@D)
	lipo -create $^ -output $@
	lipo $@ -archs

lib/libgmp.a: arm64_big_sur/gmp/6.2.1_1/lib/libgmp.a big_sur/gmp/6.2.1_1/lib/libgmp.a
	mkdir -p $(@D)
	lipo -create $^ -output $@
	lipo $@ -archs

lib/libunistring.a: arm64_big_sur/libunistring/0.9.10/lib/libunistring.a big_sur/libunistring/0.9.10/lib/libunistring.a
	mkdir -p $(@D)
	lipo -create $^ -output $@
	lipo $@ -archs

.PHONY: verify
verify: lib/libguile-3.0.a lib/libgc.a lib/libgmp.a lib/libunistring.a

.PHONY: headers
headers: include/libguile.h include/gmp.h

include/libguile.h: big_sur/guile/3.0.7_2/include/guile/3.0/ .FORCE
	rsync -av $< include

include/gmp.h: big_sur/gmp/6.2.1_1/include/ .FORCE
	rsync -av $< include

.PHONY: clean
clean:
	-rm -rf big_sur
	-rm -rf arm64_big_sur
	-rm -rf include
	-rm -rf lib

.PHONY: .FORCE
.FORCE:

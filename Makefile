SWIFTC ?= swiftc
SWIFTFLAGS = -O -whole-module-optimization
FRAMEWORKS = -framework AppKit -framework Network

SOURCES := $(shell find Sources -name '*.swift')
APP_SOURCES := $(filter-out Tests/%,$(SOURCES))

# Test sources: all app sources except main.swift, plus test files
APP_LIB := $(filter-out Sources/App/main.swift,$(APP_SOURCES))
TESTS := $(wildcard Tests/Unit/*.swift)

# Swift Testing framework paths
PLATFORM := /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer
TOOLCHAIN := /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain
TESTFLAGS := -parse-as-library \
             -F $(PLATFORM)/Library/Frameworks \
             -plugin-path $(TOOLCHAIN)/usr/lib/swift/host/plugins/testing \
             -Xlinker -rpath -Xlinker $(PLATFORM)/Library/Frameworks

PREFIX ?= /usr/local

.PHONY: all clean install test

all: .build/kanata-cheatsheet

.build:
	mkdir -p .build

.build/kanata-cheatsheet: $(APP_SOURCES) | .build
	$(SWIFTC) $(SWIFTFLAGS) -o $@ $(APP_SOURCES) $(FRAMEWORKS)

.build/tests: $(APP_LIB) $(TESTS) | .build
	$(SWIFTC) $(TESTFLAGS) -o $@ $(APP_LIB) $(TESTS) $(FRAMEWORKS)

test: .build/tests
	.build/tests

clean:
	rm -rf .build

install: all
	install -d $(PREFIX)/bin
	install -m 755 .build/kanata-cheatsheet $(PREFIX)/bin/kanata-cheatsheet

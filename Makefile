.PHONY: build run release test lint clean install screenshots

CONFIG ?= debug

build:
	@swift build -c $(CONFIG)

run: build
	@./.build/$(CONFIG)/ClaudeHelper

app:
	@./scripts/build-app.sh $(CONFIG)

release:
	@./scripts/build-app.sh release

test:
	@swift test

lint:
	@swift format lint --recursive Sources Tests || true

clean:
	@swift package clean
	@rm -rf .build dist

install: release
	@cp -R dist/ClaudeHelper.app /Applications/
	@open /Applications/ClaudeHelper.app

screenshots: build
	@CLAUDEHELPER_SCREENSHOT_MODE=1 ./.build/$(CONFIG)/ClaudeHelper

# ccmeter — local dev helpers.
# All targets run from the repo root.

XCODEBUILD := xcrun xcodebuild
PROJECT    := ccmeter.xcodeproj
SCHEME     := ccmeter
CONFIG     := Release
BUILD_DIR  := build
APP        := $(BUILD_DIR)/Build/Products/$(CONFIG)/ccmeter.app
DIST_DIR   := dist
DMG        := $(DIST_DIR)/ccmeter-dev.dmg

ICONSET    := ccmeter/Assets.xcassets/AppIcon.appiconset
ICON_SIZES := 16 32 64 128 256 512 1024
ICON_PNGS  := $(foreach s,$(ICON_SIZES),$(ICONSET)/icon_$(s).png)

XCODEBUILD_FLAGS := \
	-project $(PROJECT) \
	-scheme $(SCHEME) \
	-configuration $(CONFIG) \
	-derivedDataPath $(BUILD_DIR) \
	CODE_SIGN_IDENTITY=- \
	CODE_SIGNING_REQUIRED=NO \
	CODE_SIGNING_ALLOWED=NO

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@awk 'BEGIN{FS=":.*##"; printf "\nTargets:\n"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: icons
icons: $(ICON_PNGS) ## Regenerate all AppIcon PNGs from logo.svg

$(ICONSET)/icon_%.png: logo.svg
	@command -v rsvg-convert >/dev/null || { echo "rsvg-convert not found. brew install librsvg"; exit 1; }
	rsvg-convert -w $* -h $* $< -o $@

.PHONY: fixtures
fixtures: ## Re-capture ccusage JSON fixtures into Tests/Fixtures/
	@mkdir -p Tests/Fixtures
	ccusage daily   --json > Tests/Fixtures/daily.json
	ccusage session --json > Tests/Fixtures/session.json
	ccusage blocks  --json > Tests/Fixtures/blocks.json

.PHONY: generate
generate: ## Regenerate ccmeter.xcodeproj via xcodegen
	@command -v xcodegen >/dev/null || { echo "xcodegen not found. brew install xcodegen"; exit 1; }
	xcodegen generate

.PHONY: build
build: $(PROJECT) ## Build Release .app via xcodebuild
	$(XCODEBUILD) $(XCODEBUILD_FLAGS)

$(PROJECT): project.yml
	$(MAKE) generate

.PHONY: run
run: build ## Build then relaunch the .app from Finder (LaunchServices, like a real user)
	-pkill -x ccmeter
	@sleep 0.3
	open $(APP)

.PHONY: dmg
dmg: build ## Build a local DMG identical to CI (unsigned)
	@command -v create-dmg >/dev/null || { echo "create-dmg not found. brew install create-dmg"; exit 1; }
	@mkdir -p $(DIST_DIR)
	@rm -f $(DMG)
	create-dmg \
		--volname "ccmeter dev" \
		--window-pos 200 120 \
		--window-size 540 320 \
		--icon-size 96 \
		--icon "ccmeter.app" 140 150 \
		--hide-extension "ccmeter.app" \
		--app-drop-link 400 150 \
		--no-internet-enable \
		$(DMG) \
		$(APP)
	@echo "DMG: $(DMG)"

.PHONY: clean
clean: ## Remove build/, dist/, and the generated .xcodeproj
	rm -rf $(BUILD_DIR) $(DIST_DIR) $(PROJECT)

.PHONY: kill
kill: ## Stop any running ccmeter instance
	-pkill -x ccmeter

.PHONY: sdk-version

# SDK 소스 버전과 Example CocoaPods 메타데이터를 한 번에 갱신한다.
sdk-version:
	@if [ -z "$(VERSION)" ]; then \
		echo "Usage: make sdk-version VERSION=x.y.z"; \
		exit 1; \
	fi
	@ruby scripts/set_sdk_version.rb "$(VERSION)"

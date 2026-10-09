.PHONY: all build release test app install-cli clean run-app help

PREFIX ?= /usr/local

all: build

help:
	@echo "AgentFloat 开发与构建命令:"
	@echo "  make build        - 调试模式编译全部 Target"
	@echo "  make release      - Release 模式编译"
	@echo "  make test         - 执行单元测试"
	@echo "  make app          - 打包生成 build/AgentFloat.app"
	@echo "  make run-app      - 打包并启动 AgentFloat.app"
	@echo "  make install-cli  - 安装 CLI 工具到 $(PREFIX)/bin/agentfloat"
	@echo "  make clean        - 清理构建产物"

build:
	swift build

release:
	swift build -c release

test:
	swift test

app:
	./scripts/build-app.sh release

run-app: app
	open build/AgentFloat.app

install-cli: release
	@mkdir -p $(PREFIX)/bin
	@cp -f .build/release/AgentFloatCLI $(PREFIX)/bin/agentfloat
	@chmod +x $(PREFIX)/bin/agentfloat
	@echo "✅ agentfloat 已安装至 $(PREFIX)/bin/agentfloat"

clean:
	rm -rf .build build

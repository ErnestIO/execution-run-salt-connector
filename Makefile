default:
	bundle install

run:
	BASH_GO_MODE=sync $(GOPATH)/bin/bash-nats execution.create.salt ruby adapter.rb

deps:
	go get -u github.com/ernestio/bash-nats

dev-deps:
	bundle install

lint:
	rubocop --fail-fast

cover:
	COVERAGE=true MIN_COVERAGE=0 bundle exec rspec -c -f d spec

test:
	bundle exec rspec -c -f d spec

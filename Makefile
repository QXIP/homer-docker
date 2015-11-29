build:
	docker build --tag="qxip/homer-docker:latest" ./ .

run:
	docker run -ti --name homer5 -p 80:80 -p 9060:9060 qxip/homer-docker:latest

run-container:
	docker run -tid --name homer5 -p 80:80 -p 9060:9060 qxip/homer-docker

test:
	curl localhost

.PHONY: install build run test clean

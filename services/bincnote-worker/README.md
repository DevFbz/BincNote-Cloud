Build docker image for bincnote worker manually

```shell
docker buildx build -f ./services/bincnote-worker/Dockerfile  --platform linux/amd64 -t bincnoteinc/bincnote_worker --push .
```
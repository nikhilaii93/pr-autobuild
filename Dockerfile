FROM alpine:latest
LABEL "com.github.actions.name"="PR Build & Merge"
LABEL "com.github.actions.description"="Automatically Builds & Merges after approval and optional label"
LABEL "com.github.actions.icon"="check-square"
LABEL "com.github.actions.color"="blue"
RUN	apk add --no-cache \
	bash \
	ca-certificates \
	curl \
	jq
COPY /bin /usr/bin/
ENTRYPOINT ["autobuild.sh"]
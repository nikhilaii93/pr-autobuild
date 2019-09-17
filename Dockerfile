FROM alpine:latest
LABEL "com.github.actions.name"="PR Build"
LABEL "com.github.actions.description"="Build PR once it's approved"
LABEL "com.github.actions.icon"="activity"
LABEL "com.github.actions.color"="red"
RUN	apk add --no-cache \
	bash \
	ca-certificates \
	curl \
	jq
COPY /bin /usr/bin/
ENTRYPOINT ["autobuild.sh"]
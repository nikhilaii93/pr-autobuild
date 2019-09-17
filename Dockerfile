FROM ubuntu:16.04
LABEL "com.github.actions.name"="PR Build"
LABEL "com.github.actions.description"="Build PR once it's approved"
LABEL "com.github.actions.icon"="activity"
LABEL "com.github.actions.color"="red"
RUN apt-get update && \
    apt-get install -y jq
COPY /bin /usr/bin/
ENTRYPOINT ["autobuild.sh"]
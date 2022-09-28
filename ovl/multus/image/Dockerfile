FROM alpine:latest
RUN apk add jq
ADD --chown=0:0 ovl.tar /
CMD ["/root/multus-installer.sh", "install"]

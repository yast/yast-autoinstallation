FROM registry.opensuse.org/yast/head/containers/yast-ruby:latest
RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends \
  trang \
  libxml2-tools \
  libxslt-tools \
  yast2-installation-control \
  yast2-update
COPY . /usr/src/app

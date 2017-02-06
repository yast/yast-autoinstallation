FROM yastdevel/storage-ng
RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends \
  trang \
  libxml2-tools \
  libxslt-tools \
  yast2-installation-control
COPY . /usr/src/app

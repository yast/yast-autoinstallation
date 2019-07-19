FROM yastdevel/ruby:sle12-sp5


RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends \
  trang \
  libxml2-tools \
  libxslt-tools
COPY . /usr/src/app


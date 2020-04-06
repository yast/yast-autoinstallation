FROM yastdevel/ruby:sle12-sp3
RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends --force-resolution --oldpackage \
  trang \
  libxml2-tools \
  libxslt-tools
COPY . /usr/src/app


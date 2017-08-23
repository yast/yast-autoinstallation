# FIXME: using this special image in Travis is still needed while the merge of
# storage-ng and master is not complete. It should be switched to YaST standard
# docker image soon.
FROM yastdevel/ruby
RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends \
  trang \
  libxml2-tools \
  libxslt-tools \
  yast2-installation-control \
  yast2-update
COPY . /usr/src/app

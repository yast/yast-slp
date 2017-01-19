FROM yastdevel/cpp
RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends \
  openslp-devel \
  yast2 \
  yast2-ruby-bindings
COPY . /usr/src/app

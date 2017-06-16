FROM yastdevel/ruby:sle12-sp3
RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends \
  gcc-c++ \
  libtool \
  openslp-devel \
  yast2-core-devel
COPY . /usr/src/app

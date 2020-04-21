FROM registry.opensuse.org/yast/sle-15/sp2/containers/yast-ruby
RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends \
  gcc-c++ \
  libtool \
  openslp-devel \
  yast2-core-devel
COPY . /usr/src/app

# Ganeti RPM Packaging

Ganeti RPM Packaging for RHEL/CentOS/others.

## Packaging status

- RHEL/CentOS/others 8.x: 2.16.2-1
    - testing: 3.0.0.rc1-2
- RHEL/CentOS/others 7.x: 2.16.2-1
    - testing: 3.0.0.rc1-2

## Documentation

- [Installation and Upgrade guides](https://github.com/jfut/ganeti-rpm/tree/master/doc)

## YUM repository and binary RPM files

- http://jfut.integ.jp/linux/ganeti/

## Building RPM Packages with Docker

You can build RPM packages in Docker.

```
# CentOS 8
./build centos:8

# CentOS 7
./build centos:7
```

Debug and manual mode:

```
# CentOS 8
./build -d centos:8

# CentOS 7
./build -d centos:7

# Setup
cd /pkg
./setup

# Build
./build-rpm ...
```

## Usage: build

Run on host.

```
Usage:
    build [-d] BUILD_IMAGE_NAME:BUILD_IMAGE_TAG

    Options:
        -d Debug mode

    Environment variables:
        BUILD_HOSTNAME: container host name

    Build for CentOS 8:
        build centos:8

    Build for CentOS 7:
        build centos:7
```

## Usage: build-rpm

Run in a container.

```
Usage:
    build-rpm [-a|-d|-p] [-c|-C] [-b] [-s] [-i] [-u] [-o yes|no] [package...]

    Target Options:
        -a all packages (ganeti and its dependencies and integ-ganeti repo, snf-image)
        -d ganeti dependencies packages only
        -p the specified package(s) only. Available packages are:
            ganeti dependencies (el8 only):
                python-bitarray
            ganeti dependencies (el7 only):
                python-inotify
            ganeti:
                ganeti ganeti-instance-debootstrap
            snf-image:
                python-prctl snf-image
            integ-ganeti-repo:
                integ-ganeti-release

    Task Options:
        -c Clean clean the rpmbuild directory, but preserve downloaded archives
        -C Completely clean the rpmbuild directory

        -b Build packages
        -o Overwrite built package: yes|no (Default: manual)

        -s Sign built packages

        -i Install built packages
        -u Uninstall installed packages

        Task Execution Order:
            Uninstall -> Clean -> Build -> Sign -> Install

        If the build (-b) and install (-i) options are specified at the same time,
        the installation will be done immediately after the individual packages are built.
        This is to resolve dependencies needed to build the next package.
```

### Run build command in the container

All packages + uninstall, clean, build, and install:

```
./build-rpm -a -ucbi
```

Ganeti dependencies packages + uninstall, clean, build, and install:

```
./build-rpm -d -ucbi
```

The specified package(s) + uninstall, clean, build, and install:

```
./build-rpm -p -ucbi PACKAGE
```

Build all packages with no overwrite and install:

```
./build-rpm -a -bi -o no
```

Build the new ganeti RPM package version using the already released dependency libraries and install:

```
yum install http://jfut.integ.jp/linux/ganeti/7/x86_64/integ-ganeti-release-7-2.el7.noarch.rpm
yum-config-manager --enable integ-ganeti
./build-rpm -p -bi ganeti
```

## Signing RPM Packages

Run the container with bash:

```
# CentOS 8
BUILD_HOSTNAME=rpmbuild.centos7.docker
docker run -h ${BUILD_HOSTNAME} --rm -it -v $PWD:/pkg -v ~/.gnupg:/root/.gnupg centos:8 bash

# CentOS 7
BUILD_HOSTNAME=rpmbuild.centos8.docker
docker run -h ${BUILD_HOSTNAME} --rm -it -v $PWD:/pkg -v ~/.gnupg:/root/.gnupg centos:7 bash

# Setup
yum -y install rpm-sign

# Set your gpg name
echo "%_gpg_name jfut-rpm@integ.jp" >> ~/.rpmmacros
```

Sign all packages:

```
cd /pkg
./build-rpm -a -s
```

Sign the specified package(s) only:

```
./build-rpm -p -s PACAKGE
```

## Other Ganeti resources

- [Ganeti](http://www.ganeti.org/)
- [Ganeti Source Repository (GitHub)](https://github.com/ganeti/ganeti)
- [Ganeti's documentation](http://docs.ganeti.org/ganeti/current/html/)

## Contributing

1. Fork it
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create new Pull Request


# Previous work on OnlyOffice done by bTactic

## What we have done

- OnlyOffice binaries build with unlimited patches
- Debian package for OnlyOffice binaries with unlimited patches

## What we have not done

- RPM package for OnlyOffice binaries with unlimited patches
- Docker image containing those OnlyOffice binaries
- Brand customizations

## Main organization

The main organization where we have centralized our unlimited patches and our mostly automated build of OnlyOffice is:
[https://github.com/btactic-oo].

Repos:

- [unlimited-onlyoffice-package-builder](https://github.com/btactic-oo/unlimited-onlyoffice-package-builder): Helps to build onlyoffice binaries with unlimited patches applied to it. Also helps those same built binaries to be built into a Debian package.
- [build_tools](https://github.com/btactic-oo/build_tools): Has some custom modifications so that a few repos can be fetched from btactic-oo instead of from official onlyoffice organization. These changes were needed in 2024 but they are not currently needed with the current build approach.
- [document-server-package](https://github.com/btactic-oo/document-server-package). From time to time this package is kind of broken and needs to be patched for it to work properly. Currently it's ok. Quite old releases were built from this package.
- [web-apps](https://github.com/btactic-oo/web-apps). isSupportEditFeature is set to true. That probably means that document, presentation and spreadsheet mobile **web** editors are now being enabled. Default FOSS packages from OO do not have that feature enabled.
- [server](https://github.com/btactic-oo/server). License connection updated from 20 to 99999. As you can see this does not actually remove the license connection limit but it's good enough for most of the usecases. I guess that in the end we want to know where those connection limits are checked and remove the actual check.

## Manual work on packaging OnlyOffice - DISCARDED

Back in the day (2021) there was not an official way of building a Debian package so [I recreated their deb package builds](https://github.com/btactic-oo/build_tools/commits/debian-package/). After opening a [pull request](https://github.com/ONLYOFFICE/build_tools/pull/338) they decided to open the [document-server-package](https://github.com/ONLYOFFICE/document-server-package/) repo.

They ignore [some of my issues](https://github.com/ONLYOFFICE/document-server-package/issues/355) and [pull requests](https://github.com/ONLYOFFICE/document-server-package/pull/410). So it's not as supported as the build_tools repo when you get feedback from time to time but, we have a proper repo for these kind of builds.

## About mobile web editor support

**web-apps** have document, presentation and spreadsheet **mobile web** editors being turned on. This is probably different than the **App mobile** support that was present in v5, v6 which was discussed in the meet we had.

## About Deb packages

The bTactic Deb package built by **unlimited-onlyoffice-package-builder** is 98% equivalent to Onlyoffice Debian package because you somehow need to install their package first before installing the bTactic one. Otherwise it does not work as expected.

## About Docker image

As I said we haven't worked on producing a docker image but there's the work from thomisus:
- Git repo: [https://github.com/thomisus/Docker-DocumentServer]
- Docker image: [https://hub.docker.com/r/thomisus/onlyoffice-documentserver-unlimited]
- Nextcloud thread (search for thomisus posts): [https://help.nextcloud.com/t/onlyoffice-compiled-with-mobile-edit-back/79282]
